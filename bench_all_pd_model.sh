#!/bin/bash

DEVICE=$1
export ANDROID_SERIAL=${DEVICE}
RUNMODE=$2 # release | profile
MODEL_SET_DIR=$3
OUTPUT_DIR=$4

ADB_WORK_DIR=/data/local/tmp/zhangwen
adb shell mkdir ${ADB_WORK_DIR}

function upload_model(){
    MODEL_DIR=$1
    adb shell rm -rf ${ADB_WORK_DIR}/test_op
    adb shell mkdir ${ADB_WORK_DIR}/test_op
    adb push $MODEL_DIR/. ${ADB_WORK_DIR}/test_op
}

function run_model() {
    RUNMODE=$1
    MODEL_DIR=$2
    INPUT_ARG=$3

    REMOTE_EXEC_FILE=""
    if [ "$RUNMODE" = "release" ]; then
        REMOTE_EXEC_FILE=${ADB_WORK_DIR}/model_exec_release # prepared by user
    fi

    if [ "$RUNMODE" = "profile" ]; then
        REMOTE_EXEC_FILE=${ADB_WORK_DIR}/model_exec_profile # prepared by user
    fi

    adb shell ${REMOTE_EXEC_FILE} "--model_dir=${ADB_WORK_DIR}/test_op" $INPUT_ARG
}

function run_all() {
    ARCH=$1
    if [ "$ARCH" = "arm" ]; then
        adb push bench_binary/model_exec_release_arm ${ADB_WORK_DIR}/model_exec_release
        adb push bench_binary/model_exec_profile_arm ${ADB_WORK_DIR}/model_exec_profile
    fi

    if [ "$ARCH" = "arm64" ]; then
        adb push bench_binary/model_exec_release_arm64 ${ADB_WORK_DIR}/model_exec_release
        adb push bench_binary/model_exec_profile_arm64 ${ADB_WORK_DIR}/model_exec_profile
    fi

    for f in $(find $MODEL_SET_DIR -name '__model__'); do
        MODEL_DIR=$(dirname $f)
        MODEL_NAME=$(basename $MODEL_DIR)
        upload_model ${MODEL_DIR}
        run_model ${RUNMODE} ${MODEL_DIR} "--input_info=0 --threads=1 --power_mode=0" | tee ${OUTPUT_DIR}/${MODEL_NAME}_${ARCH}_${RUN_MODE}_thread_1.txt
        run_model ${RUNMODE} ${MODEL_DIR} "--input_info=0 --threads=2 --power_mode=0" | tee ${OUTPUT_DIR}/${MODEL_NAME}_${ARCH}_${RUN_MODE}_thread_2.txt
        run_model ${RUNMODE} ${MODEL_DIR} "--input_info=0 --threads=4 --power_mode=0" | tee ${OUTPUT_DIR}/${MODEL_NAME}_${ARCH}_${RUN_MODE}_thread_4.txt
    done
}

run_all arm
run_all arm64
