#!/bin/bash

TEST_NAME=surreal-run-c2f
TOTAL_ITER=500
TOTAL_EPOCH=5
BATCH_SIZE=2

EXP_DIR="exp"
SRC_DIR="src"
DATASET="surreal"
INPUT_RES="128"
OUT_XY_RES="32"
OUT_Z_RES="1,2,4,32"

RESTING_TIME=120

cd $SRC_DIR

LOG_PATH="../restarter.log"

DATA_PATH="/media/remi/hdd/dataset"
PROJECT_DIR=".."
EXP_PATH="$PROJECT_DIR/$EXP_DIR"
MODEL_PATH="$EXP_PATH/$DATASET/$TEST_NAME"
COMPONENTS=$(($(echo $OUT_Z_RES | grep -o ',' | wc -l) + 1))

if [ ! -d "$MODEL_PATH" ]; then
    mkdir -p $MODEL_PATH
fi

echo "" > $LOG_PATH

while [ 1 ]; do
    last=$(ls $MODEL_PATH | grep model | sed 's/^.*model_\([0-9]\+\)\.t7$/\1/' | sort -n | tail -n 1)

    if [ $last ]; then
        CONTINUE="-continue -lastEpoch $last"
    fi

    ARGS=""
    ARGS="$ARGS -dataset $DATASET"
    ARGS="$ARGS -expID $TEST_NAME"
    ARGS="$ARGS -netType hg-stacked-$COMPONENTS"
    ARGS="$ARGS -task pose-c2f"
    ARGS="$ARGS -nStack $COMPONENTS"
    ARGS="$ARGS -resZ $OUT_Z_RES"
    ARGS="$ARGS -LR 2.5e-4"
    ARGS="$ARGS -nEpochs $TOTAL_EPOCH"
    ARGS="$ARGS -trainIters $TOTAL_ITER"
    ARGS="$ARGS -validIters $TOTAL_ITER"
    ARGS="$ARGS -trainBatch $BATCH_SIZE"
    ARGS="$ARGS -inputRes $INPUT_RES"
    ARGS="$ARGS -outputRes $OUT_XY_RES"
    ARGS="$ARGS -dataDir $DATA_PATH"
    ARGS="$ARGS -source videos"
    ARGS="$ARGS -nThreads 1"
    ARGS="$ARGS $CONTINUE"

    echo th main.lua $ARGS
    th main.lua $ARGS
    # exit
    # th main.lua -dataset h36m \
    #    -expID $TEST_NAME \
    #    -netType hg-stacked-3 \
    #    -task pose-c2f \
    #    -nStack 2 \
    #    -resZ 1,2,4,64 \
    #    -LR 2.5e-4 \
    #    -nEpochs $TOTAL_EPOCH \
    #    -trainIters $TOTAL_ITER \
    #    -validIters $TOTAL_ITER \
    #    -trainBatch 2 \
    #    $CONTINUE

    echo "restarted at $last" >> $LOG_PATH

    echo -n "Sleeping $RESTING_TIME seconds..."
    sleep $RESTING_TIME
    echo "...Done"

done
