// Copyright (c) 2019 PaddlePaddle Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <gflags/gflags.h>
#include <gtest/gtest.h>
#include <vector>
#include "lite/api/cxx_api.h"
#include "lite/api/paddle_use_kernels.h"
#include "lite/api/paddle_use_ops.h"
#include "lite/api/paddle_use_passes.h"
#include "lite/api/test_helper.h"
#include "lite/core/op_registry.h"


DEFINE_string(
    input_info,
    "",
    "format: type_id input0dim_size  dim0 [dim1]... [value0]... | .... |");

namespace paddle {
namespace lite {

template <class T, class PredictorT>
struct FixDim {};

template <class T>
struct FixDim<T, lite_api::PaddlePredictor> {
  static std::vector<int64_t> Run(lite_api::PaddlePredictor* predictor,
                                  int tensor_id) {
    auto shape = predictor->GetInput(tensor_id)->shape();
    std::cout << "PaddlePredictor:shape repaired to" << std::endl;
    for (int i = 0; i < shape.size(); ++i) {
      if (shape[i] == -1) {
        shape[i] = 1;
      }
      std::cout << shape[i] << std::endl;
    }
    predictor->GetInput(tensor_id)->Resize(shape);
    return shape;
  }
};

template <class T>
struct FixDim<T, lite::Predictor> {
  static std::vector<int64_t> Run(lite::Predictor* predictor, int tensor_id) {
    auto shape = predictor->GetInput(tensor_id)->dims().Vectorize();
    std::cout << "Predictor:shape repaired to" << std::endl;
    for (int i = 0; i < shape.size(); ++i) {
      if (shape[i] == -1) {
        shape[i] = 1;
      }
      std::cout << shape[i] << std::endl;
    }
    predictor->GetInput(tensor_id)->Resize(shape);

    return shape;
  }
};

template <class T, class PredictorT>
void fill_one_tensor(PredictorT* predictor,
                     std::stringstream* line_ss_in,
                     int tensor_id) {
  auto& line_ss = *line_ss_in;
  auto dims = FixDim<T, PredictorT>::Run(predictor, tensor_id);

  // fill value with 1 first
  auto input_tensor = predictor->GetInput(tensor_id);
  auto data = input_tensor->template mutable_data<T>();
  int item_size = 1;
  for (int i = 0; i < dims.size(); ++i) {
    item_size *= dims[i];
  }
  for (int i = 0; i < item_size; i++) {
    float v = 1.0;
    data[i] = v;
  }
  int offset = 0;
  T value = 0;
  while (line_ss >> value) {
    data[offset] = value;
    ++offset;
  }
}
template <class PredictorT>
void PrePareInput(PredictorT* predictor) {
  std::stringstream input_info_ss;
  auto tmp = FLAGS_input_info;
  for (int i = 0; i < tmp.size(); ++i) {
    if (tmp[i] == ',') {
      tmp[i] = ' ';
    }
  }

  input_info_ss << tmp;

  std::string line;
  int tensor_id = 0;
  while (std::getline(input_info_ss, line, '/')) {
    std::stringstream line_ss;
    line_ss << line;
    int value_type_id = 0;
    line_ss >> value_type_id;
    switch (value_type_id) {
      case 0: {
        fill_one_tensor<float>(predictor, &line_ss, tensor_id);
        break;
      }
      case 1: {
        fill_one_tensor<int>(predictor, &line_ss, tensor_id);
        break;
      }
      default: { throw "Error"; }
    }
    ++tensor_id;
  }
}

double run_k_times(lite::Predictor* predictor, int k) {
  double sum_duration = 0.0;  // millisecond;
  for (int i = 0; i < k; ++i) {
    std::cout << "new loop runing." << std::endl;
    struct timeval ts, te;
    gettimeofday(&ts, NULL);
    predictor->Run();
    gettimeofday(&te, NULL);
    double duration =
        (te.tv_sec - ts.tv_sec) * 1e3 + (te.tv_usec - ts.tv_usec) / 1e3;
    std::cout << "this run duration: " << duration << std::endl;
    sum_duration += duration;
  }
  return sum_duration / k;
}
bool AutoLoadModel(lite::Predictor * predictor){
  std::vector<Place> valid_places({Place{TARGET(kARM), PRECISION(kInt8)},
                                   Place{TARGET(kARM), PRECISION(kInt32)},
                                   Place{TARGET(kARM), PRECISION(kFloat)},
                                   Place{TARGET(kARM), PRECISION(kInt16)},
                                   Place{TARGET(kARM), PRECISION(kFP16)},
                                   Place{TARGET(kARM), PRECISION(kInt64)}});

  bool dd_params_exisit =
      access((FLAGS_model_dir + "/__params__").c_str(), F_OK) != -1;
  bool parmas_exist = access((FLAGS_model_dir + "/params").c_str(), F_OK) != -1;
  bool dd_model_exisit =
      access((FLAGS_model_dir + "/__model__").c_str(), F_OK) != -1;
  bool model_exist = access((FLAGS_model_dir + "/model").c_str(), F_OK) != -1;
  if (dd_model_exisit) {
    if (dd_params_exisit) {
      predictor->Build(FLAGS_model_dir,
                       FLAGS_model_dir + "/__model__",
                       FLAGS_model_dir + "/__params__",
                       valid_places);
    } else {
      predictor->Build(FLAGS_model_dir, "", "", valid_places);
    }
  } else {
    if (model_exist && parmas_exist) {
      predictor->Build(FLAGS_model_dir,
                       FLAGS_model_dir + "/model",
                       FLAGS_model_dir + "/params",
                       valid_places);
    } else {
      std::cout << "Fatal Error: No model file detected" << std::endl;
      return false;
    }
  }
  return true;
}
void TestModel() {
  DeviceInfo::Init();
  DeviceInfo::Global().SetRunMode(static_cast<lite_api::PowerMode>(FLAGS_power_mode), FLAGS_threads);
  std::cout << "Threads num Set to " << FLAGS_threads << " On PowerMode "
            << FLAGS_power_mode << std::endl;
  lite::Predictor predictor;
  if(!AutoLoadModel(&predictor)){
    return;
  }

  PrePareInput(&predictor);

  double guess_time = run_k_times(&predictor, 2);

  double BENCH_TIME = 20 * 1000;  // ms
  int bench_count = std::max(4.0, BENCH_TIME / guess_time);
  int warm_up_count = std::max(1, bench_count / 4);

  run_k_times(&predictor, warm_up_count);
  double bench_avg_time = run_k_times(&predictor, bench_count);

  std::cout << "warm up " << warm_up_count << " times" << std::endl;
  std::cout << "benchmark loops " << bench_count << " times."
            << " avg time: " << bench_avg_time << " ms" << std::endl;
}

TEST(MobileNetV1, test_arm) { TestModel(); }

}  // namespace lite
}  // namespace paddle
