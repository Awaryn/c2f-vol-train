-------------------------------------------------------------------------------
-- Load necessary libraries and files
-------------------------------------------------------------------------------

require 'torch'
require 'xlua'
require 'optim'
require 'nn'
require 'nnx'
require 'nngraph'
require 'hdf5'
require 'string'
require 'image'

paths.dofile('util/img.lua')
paths.dofile('util/eval.lua')
paths.dofile('util/Logger.lua')

torch.setdefaulttensortype('torch.FloatTensor')

-- Project directory
projectDir = paths.concat(os.getenv('HOME'),'c2f-vol-train')

-------------------------------------------------------------------------------
-- Process command line options
-------------------------------------------------------------------------------

if not opt then

local opts = paths.dofile('opts.lua')
opt = opts.parse(arg)

print('Saving everything to: ' .. opt.save)
os.execute('mkdir -p ' .. opt.save)

if opt.GPU == -1 then
    nnlib = nn
else
    require 'cutorch'
    require 'cunn'
    require 'cudnn'
    nnlib = cudnn
    cutorch.setDevice(opt.GPU)
end

if opt.branch ~= 'none' or opt.continue then
    -- Continuing training from a prior experiment
    -- Figure out which new options have been set
    local setOpts = {}
    for i = 1,#arg do
        if arg[i]:sub(1,1) == '-' then table.insert(setOpts,arg[i]:sub(2,-1)) end
    end

    -- Where to load the previous options/model from
    if opt.branch ~= 'none' then opt.load = opt.expDir .. '/' .. opt.branch
    else opt.load = opt.expDir .. '/' .. opt.expID end

    -- Keep previous options, except those that were manually set
    local opt_ = opt
    opt = torch.load(opt_.load .. '/options.t7')
    opt.save = opt_.save
    opt.load = opt_.load
    opt.continue = opt_.continue
    for i = 1,#setOpts do opt[setOpts[i]] = opt_[setOpts[i]] end

    epoch = opt.lastEpoch + 1
    
    -- If there's a previous optimState, load that too
    if paths.filep(opt.load .. '/optimState.t7') then
        optimState = torch.load(opt.load .. '/optimState.t7')
        optimState.learningRate = opt.LR
    end

else epoch = 1 end
opt.epochNumber = epoch

-- Training hyperparameters
-- (Some of these aren't relevant for rmsprop which is the optimization we use)
if not optimState then
    optimState = {
        learningRate = opt.LR,
        learningRateDecay = opt.LRdecay,
        momentum = opt.momentum,
        dampening = 0.0,
        weightDecay = opt.weightDecay
    }
end

-- Optimization function
optfn = optim[opt.optMethod]

-- Random number seed
if opt.manualSeed ~= -1 then torch.manualSeed(opt.manualSeed)
else torch.seed() end                           

-- Save options to experiment directory
torch.save(opt.save .. '/options.t7', opt)

end

-------------------------------------------------------------------------------
-- Load in annotations
-------------------------------------------------------------------------------

annotLabels = {'train', 'valid'}
annot,ref = {},{}
for _,l in ipairs(annotLabels) do
    local a, namesFile
    a = hdf5.open(opt.dataDir .. '/annot/' .. l .. '.h5')
    annot[l] = {}

    -- Read in annotation information
    annot[l]['part'] = a:read('part'):all()
    annot[l]['center'] = a:read('center'):all()
    annot[l]['scale'] = a:read('scale'):all()
    annot[l]['zind'] = a:read('zind'):all()
    annot[l]['nsamples'] = annot[l]['part']:size()[1]

    -- local tags = {'part', 'center', 'scale', 'zind'}
    -- for _,tag in ipairs(tags) do annot[l][tag] = a:read(tag):all() end
    namesFile = io.open(opt.dataDir .. '/annot/' .. l .. '_' .. opt.source ..'.txt')
    if opt.source == 'images' then
       -- Load in image file names (reading strings wasn't working from hdf5)
       annot[l]['images'] = {}
       local idx = 1
       for line in namesFile:lines() do
          annot[l]['images'][idx] = line
          idx = idx + 1
       end
       -- Loading from videos
    else
       annot[l]['videos'] = {}
       local idx = 1
       for line in namesFile:lines() do
          annot[l]['videos'][idx] = line
          idx = idx + 1
       end
       annot[l]['video_id'] = a:read('video_id'):all()
       annot[l]['frame_id'] = a:read('frame_id'):all()
    end
    namesFile:close()

    -- Set up reference for training parameters
    ref[l] = {}
    ref[l].nsamples = annot[l]['nsamples']
    ref[l].iters = opt[l .. 'Iters']
    ref[l].batchsize = opt[l .. 'Batch']
    ref[l].log = Logger(paths.concat(opt.save, l .. '.log'), opt.continue)
end

ref.predict = {}
ref.predict.nsamples = annot.valid.nsamples
ref.predict.iters = annot.valid.nsamples
ref.predict.batchsize = 1

-- Default input is assumed to be an image and output is assumed to be a heatmap
-- This can change if an hdf5 file is used, or if opt.task specifies something different
nParts = annot['train']['part']:size(2)
dataDim = {3, opt.inputRes, opt.inputRes}
labelDim = {nParts, opt.outputRes, opt.outputRes}

-- Load up task specific variables/functions
-- (this allows a decent amount of flexibility in network input/output and training)
paths.dofile('util/' .. opt.task .. '.lua')

local matchedParts
if opt.dataset == 'mpii' then
     matchedParts = {
         {1,6},   {2,5},   {3,4},
         {11,16}, {12,15}, {13,14}
    }
elseif opt.dataset == 'flic' then
    matchedParts = {
        {1,4}, {2,5}, {3,6}, {7,8}, {9,10}
    }
elseif opt.dataset == 'lsp' then
    matchedParts = {
        {1,6}, {2,5}, {3,4}, {7,12}, {8,11}, {9,10}
    }
elseif opt.dataset == 'h36m' then
    matchedParts = {
        {2,5}, {3,6}, {4,7}, {12,15}, {13,16}, {14,17}
    }
elseif opt.dataset == 'surreal' then
    matchedParts = {
       { 2,  3}, { 5,  6}, { 8,  9},
       {11, 12}, {14, 15}, {17, 18},
       {19, 20}, {21, 22}, {23, 24},
    }
end

matchedParts3D = {}
for i = 1, opt.nStack do
    local matchTemp = {}
    for j = 1,#matchedParts do
        for k = 1,opt.resZ[i] do
             table.insert(matchTemp,{(matchedParts[j][1]-1)*opt.resZ[i]+k,(matchedParts[j][2]-1)*opt.resZ[i]+k})
        end
    end
    matchedParts3D[i] = matchTemp
end

function applyFn(fn, t, t2)
    -- Helper function for applying an operation whether passed a table or tensor
    local t_ = {}
    if type(t) == "table" then
        if t2 then
            for i = 1,#t do t_[i] = applyFn(fn, t[i], t2[i]) end
        else
            for i = 1,#t do t_[i] = applyFn(fn, t[i]) end
        end
    else t_ = fn(t, t2) end
    return t_
end
