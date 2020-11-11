#!/bin/bash

DEVICE=$1
export ANDROID_SERIAL=${DEVICE}
RUN_MODE=$2 # release | profile
MODEL_SET_DIR=$3
OUTPUT_DIR=$4
mkdir -p $OUTPUT_DIR

ADB_WORK_DIR=/data/local/tmp/zhangwen
adb shell mkdir ${ADB_WORK_DIR}

function upload_model(){
    MODEL_FILE=$1
    adb shell rm -rf ${ADB_WORK_DIR}/tmp.tflite
    adb push ${MODEL_FILE} ${ADB_WORK_DIR}/tmp.tflite
}

function run_model() {
    RUN_MODE=$1
    MODEL_FILE=$2
    THREAD_NUM=$3
    EXTRA_ARG=""
    if [ "$RUN_MODE" = "profile" ]; then
        EXTRA_ARG="--enable_op_profiling"
    fi
    
    REMOTE_EXEC_FILE=${ADB_WORK_DIR}/tf_benchmark


    adb shell ${REMOTE_EXEC_FILE} \
        --num_threads=${THREAD_NUM} \
        --graph=${ADB_WORK_DIR}/tmp.tflite \
        ${EXTRA_ARG} --use_xnnpack=true
}

function run_all() {
    ARCH=$1
    if [ "$ARCH" = "arm" ]; then
        adb push bench_binary/tf_benchmark_arm ${ADB_WORK_DIR}/tf_benchmark
    fi

    if [ "$ARCH" = "arm64" ]; then
        adb push bench_binary/tf_benchmark_arm64 ${ADB_WORK_DIR}/tf_benchmark
    fi
    for MODEL_FILE in $(find $MODEL_SET_DIR -name '*.tflite'); do
        MODEL_NAME=$(basename $MODEL_FILE .tflite)
        upload_model ${MODEL_FILE}
        run_model ${RUN_MODE} ${MODEL_FILE} 1 | tee ${OUTPUT_DIR}/${MODEL_NAME}_${ARCH}_${RUN_MODE}_thread_1.txt
        run_model ${RUN_MODE} ${MODEL_FILE} 2 | tee ${OUTPUT_DIR}/${MODEL_NAME}_${ARCH}_${RUN_MODE}_thread_2.txt
        run_model ${RUN_MODE} ${MODEL_FILE} 4 | tee ${OUTPUT_DIR}/${MODEL_NAME}_${ARCH}_${RUN_MODE}_thread_4.txt
    done
}

run_all arm
run_all arm64