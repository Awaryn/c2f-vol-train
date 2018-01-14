local cv = require 'cv'
require 'cv.videoio'

-- frame starts at index 0
function extractFrame(video_path, frame)

   local cap = cv.VideoCapture{filename=video_path}
   if not cap:isOpened() then
      print("Failed to open " .. video_path)
   end

   cap:set{propId=1, value=frame} --CV_CAP_PROP_POS_FRAMES

   local rgb
   if pcall(function()
         b, rgb = cap:read{};
         rgb = rgb:permute(3, 1, 2):float()/255;       -- Rescale to [0 1]
         rgb = rgb:index(1, torch.LongTensor{3, 2, 1}) -- By default, video files are loaded in BGR
           end )
   then
      return rgb
   else
      print("Failed to extract frame from " .. video_path)
      return nil
   end

end
