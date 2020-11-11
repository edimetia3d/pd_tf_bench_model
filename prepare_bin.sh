#!/bin/bash
paddlite_root=$(realpath $1)
cd bench_binary

cp template.cc $paddlite_root/lite/api/mobilenetv1_test.cc

./build_pdlite.sh $paddlite_root rebuild -DARM_TARGET_ARCH_ABI=armv8 -DLITE_WITH_PROFILE=ON -DARM_TARGET_LANG=clang
cp $paddlite_root/build/lite/api/test_mobilenetv1 model_exec_profile_arm64

./build_pdlite.sh $paddlite_root rebuild -DARM_TARGET_ARCH_ABI=armv7 -DLITE_WITH_PROFILE=ON -DARM_TARGET_LANG=gcc
cp $paddlite_root/build/lite/api/test_mobilenetv1 model_exec_profile_arm

./build_pdlite.sh $paddlite_root rebuild -DARM_TARGET_ARCH_ABI=armv8 -DARM_TARGET_LANG=clang
cp $paddlite_root/build/lite/api/test_mobilenetv1 model_exec_release_arm64

./build_pdlite.sh $paddlite_root rebuild -DARM_TARGET_ARCH_ABI=armv7 -DARM_TARGET_LANG=gcc
cp $paddlite_root/build/lite/api/test_mobilenetv1 model_exec_release_arm


./build_tflite.sh
cp tmp_build/benchmark_model_android_arm64 tf_benchmark_arm64
cp tmp_build/benchmark_model_android_arm tf_benchmark_arm