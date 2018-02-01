# Original Work

This repository is a fork on top of [Pavlakos et al](https://github.com/geopavlakos/c2f-vol-train)
repository, please refer to this link for instructions on how to install, train, etc.

# Contribution

This is a Project for the course **Object Recognition and Computer vision** of the master MVA
supervised by [Gül Varol](https://github.com/gulvarol). This has been realized in a team of 2.
In this repository, we added support for the [SURREAL](http://www.di.ens.fr/willow/research/surreal/)
dataset and used it to train the Coarse to fine Volumetric model on this dataset.
```
th main.lua ... -dataset surreal -source videos
```
The annotations must have been properly generated
(using this [repository](https://github.com/Awaryn/surreal_processing))

 ## Train with SURREAL dataset

In order to use SURREAL dataset, we first need to create the necessary symbolic links to the dataset.
The training code expect to have two set **train** and **vallid**, which are named respectively
**train** and **test** in the SURREAL dataset, so we also create symbolic links to handle this mismatch.

### 1. Create symbolic links for the dataset

Replace `PATH_TO_SURREAL` by your own path to the SURREAL dataset
```
PATH_TO_SURREAL=path/to/surreal/
mkdir -p data/surreal
ln -s $PATH_TO_SURREAL/train data/surreal/train
ln -s $PATH_TO_SURREAL/test data/surreal/valid
```

### 2. Create symbolic links for the annotation files

Replace `PATH_TO_SURREAL_ANNOTATION` by your own path to the annotation
generated with this [repository](https://github.com/Awaryn/surreal_processing) (You should process
the training set and the test set, leading to 2 h5 files `train.h5`, `test.h5` as well as 2
video list files `train_videos.h5`, `test_videos.h5`.

```
# Replace by your own path
PATH_TO_SURREAL_ANNOTATION=path/to/annotation/
mkdir -p data/surreal/annot
ln -s $PATH_TO_SURREAL_ANNOTATION/train.h5         data/surreal/annot/train.h5
ln -s $PATH_TO_SURREAL_ANNOTATION/train_videos.txt data/surreal/annot/train_videos.txt
ln -s $PATH_TO_SURREAL_ANNOTATION/test.h5          data/surreal/annot/valid.h5
ln -s $PATH_TO_SURREAL_ANNOTATION/test_videos.txt  data/surreal/annot/valid_videos.txt
```

### 3. Training

Here's the full command that we ran for our project
```
th main.lua -dataset surreal -expID surreal-run-c2f -netType hg-stacked-4 -task pose-c2f \
-nStack 4 -resZ 1,2,4,32 -LR 2.5e-4 -nEpochs 150 -trainIters 500 -validIters 500 -trainBatch 2 \
-inputRes 128 -outputRes 32 -source videos
```
### Citing

This repository only contains small modifications on top of the original
[repository](https://github.com/geopavlakos/c2f-vol-train), If you find this code useful,
please cite the original paper:

	@Inproceedings{pavlakos17volumetric,
	  Title          = {Coarse-to-Fine Volumetric Prediction for Single-Image 3{D} Human Pose},
	  Author         = {Pavlakos, Georgios and Zhou, Xiaowei and Derpanis, Konstantinos G and Daniilidis, Kostas},
	  Booktitle      = {Computer Vision and Pattern Recognition (CVPR)},
	  Year           = {2017}
	}
