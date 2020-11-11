#!/bin/bash
project_root=$1
rebuild=$2
EXTRA_CMAKE_ARGS=${@:3}
if [ -z "project_root" ]; then
    echo ERROR: must set project_root
    exit
fi

function pre_cmake(){
  project_root=$1
  build_dir=$2
  echo project_root $project_root
  echo build_dir $build_dir
  
  rm $project_root/lite/api/paddle_use_kernels.h
  rm $project_root/lite/api/paddle_use_ops.h
  
  GEN_CODE_PATH_PREFIX=lite/gen_code
  mkdir -p $build_dir/${GEN_CODE_PATH_PREFIX}
  touch $build_dir/${GEN_CODE_PATH_PREFIX}/__generated_code__.cc

  DEBUG_TOOL_PATH_PREFIX=lite/tools/debug
  mkdir -p $build_dir/${DEBUG_TOOL_PATH_PREFIX}
  cp $project_root/${DEBUG_TOOL_PATH_PREFIX}/analysis_tool.py $build_dir/${DEBUG_TOOL_PATH_PREFIX}/
  pushd $project_root
  /bin/bash -c 'source ./lite/tools/ci_build.sh;prepare_thirdparty'
  popd
}

ulimit -n 10240

export NDK_ROOT=/opt/android-ndk-r17c
CMAKE_3_10_3_PATH=/opt/cmake-3.10.3-Linux-x86_64/bin
export PATH=$CMAKE_3_10_3_PATH:$PATH

# start build
build_dir=$project_root/build

if [ $rebuild = "rebuild" ]; then
  rm -rf $build_dir
  rm -rf $project_root/third-party/*
fi

if [ ! -d $build_dir ]; then
  pre_cmake $project_root $build_dir
  cd $build_dir
    cmake -DWITH_GPU=OFF \
    -DWITH_MKL=OFF \
    -DWITH_LITE=ON \
    -DLITE_WITH_CUDA=OFF \
    -DLITE_WITH_X86=OFF \
    -DLITE_WITH_ARM=ON \
    -DWITH_ARM_DOTPROD=ON \
    -DLITE_WITH_LIGHT_WEIGHT_FRAMEWORK=ON \
    -DWITH_TESTING=ON \
    -DLITE_BUILD_EXTRA=ON \
    -DLITE_WITH_TRAIN=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DARM_TARGET_OS=android \
    ${EXTRA_CMAKE_ARGS} $project_root
else
  cd $build_dir
fi
make test_mobilenetv1 -j32


