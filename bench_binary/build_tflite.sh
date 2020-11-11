#!/bin/bash
export http_proxy=http://172.24.152.31:7087;export https_proxy=http://172.24.152.31:7087;
FORCE_REBUILD_IMAGE=OFF
set -e
BUILD_OUT_DIR=$PWD/tmp_build
mkdir -p ${BUILD_OUT_DIR}
CONTAINER_OUT_DIR=/host_dir

function build_one() {
  pushd ${BUILD_OUT_DIR}
  CONTAINER_NAME=benchmark_tflite_builder
  IMAGE_NAME=tflite-builder
  CONFIG=android_arm64
  OUT_TYPE=arm64-v8a-opt
  NDK_FILENAME=android-ndk-r18b-linux-x86_64.zip
  if [ "$1" = "armv7" ]; then
    CONTAINER_NAME=${CONTAINER_NAME}_armv7
    IMAGE_NAME=${IMAGE_NAME}_r17c
    CONFIG=android_arm
    OUT_TYPE=armeabi-v7a-opt
    NDK_FILENAME=android-ndk-r17c-linux-x86_64.zip
  fi
  
  DOCKER_BUILD_EXTRA_OPTION=""
  if [ "$FORCE_REBUILD_IMAGE" = "ON" ]; then
    DOCKER_BUILD_EXTRA_OPTION="--no-cache"
    docker container rm ${CONTAINER_NAME} -f
  fi
  
  if [ ! -f "tflite-android.Dockerfile" ]; then
    curl https://raw.githubusercontent.com/tensorflow/tensorflow/master/tensorflow/tools/dockerfiles/tflite-android.Dockerfile >tflite-android.Dockerfile
  fi
  sed 's/android-ndk-r18b-linux-x86_64.zip/'${NDK_FILENAME}'/g' tflite-android.Dockerfile > tflite-android-mod.Dockerfile
  docker build . -t ${IMAGE_NAME} ${DOCKER_BUILD_EXTRA_OPTION} -f tflite-android-mod.Dockerfile

  cat >benchmark_tflite_build.sh <<EOL
#!/bin/bash
# This script can only run in Container
cd /tensorflow_src
#git pull
COMMID_ID=\$(git rev-parse --short HEAD)
export http_proxy=http://172.19.57.45:3128;export https_proxy=http://172.19.57.45:3128
bazel build -c opt \
            --config=${CONFIG} \
            tensorflow/lite/tools/benchmark:benchmark_model
rm ${CONTAINER_OUT_DIR}/benchmark_model_${CONFIG}_*
cp bazel-out/${OUT_TYPE}/bin/tensorflow/lite/tools/benchmark/benchmark_model ${CONTAINER_OUT_DIR}/benchmark_model_${CONFIG}
EOL

  chmod +x benchmark_tflite_build.sh

  docker run -it --rm -v $PWD:${CONTAINER_OUT_DIR} --name ${CONTAINER_NAME} ${IMAGE_NAME} bash ${CONTAINER_OUT_DIR}/benchmark_tflite_build.sh

  rm benchmark_tflite_build.sh
  rm tflite-android-mod.Dockerfile
  popd
}

build_one
build_one armv7
