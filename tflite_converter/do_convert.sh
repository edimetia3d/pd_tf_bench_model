#bin/bash
SCRIPT_LOCATION=$(dirname "$(readlink -f "$0")")
cd ${SCRIPT_LOCATION}

OUTPUT_DIR=output_tflite
mkdir ${OUTPUT_DIR}

function onnx_convert() {
    FILE_PATH=$1
    INPUT_ARRAY=$2
    OUTPUT_ARRAY=$3
    OUTPUT_DIR=$4
    EXTRA_ARGS=${@:5}

    FILE_NAME=$(basename $FILE_PATH .onnx)
    onnx-tf convert -i ${FILE_PATH} -o ${FILE_NAME}.pb
    tflite_convert --graph_def_file=${FILE_NAME}.pb \
        --input_arrays=$INPUT_ARRAY \
        --output_arrays=$OUTPUT_ARRAY \
        $EXTRA_ARGS --output_file=$OUTPUT_DIR/onnx_$FILE_NAME.tflite

    rm ${FILE_NAME}.pb
}

onnx_convert /share/models/onnx_original/mobilenetv2-1.0/mobilenetv2-1.0.onnx data transpose_161 ${OUTPUT_DIR}
onnx_convert /share/models/onnx_original/resnet50/resnet50.onnx gpu_0/data_0 add_1 ${OUTPUT_DIR}
onnx_convert /share/models/onnx_original/shufflenet/shufflenet.onnx gpu_0/data_0 add_34 ${OUTPUT_DIR}
onnx_convert /share/models/onnx_original/squeezenet/squeezenet.onnx data_0 Softmax ${OUTPUT_DIR}

function caffe1_convert() {

    MODEL_PATH=$(realpath $1)
    OUTPUT_DIR=$(realpath $2)
    FILE_NAME=$(basename ${MODEL_PATH}/*.caffemodel .caffemodel)
    rm -rf tmp_caffe
    mkdir tmp_caffe
    cd tmp_caffe
    mmconvert \
        -sf caffe \
        -in ${MODEL_PATH}/*.prototxt \
        -iw ${MODEL_PATH}/*.caffemodel \
        -df tensorflow \
        --dump_tag SERVING \
        -om ./caffe_saved_model
    cd ..
    tflite_convert --saved_model_dir=./tmp_caffe/caffe_saved_model --output_file=${OUTPUT_DIR}/caffe_${FILE_NAME}.tflite
    rm -rf tmp_caffe
}

caffe1_convert /share/models/caffe_original_batch_equal_1/mnasnet ${OUTPUT_DIR}
caffe1_convert /share/models/caffe_original_batch_equal_1/mobilenetv1 ${OUTPUT_DIR}
caffe1_convert /share/models/caffe_original_batch_equal_1/mobilenetv2 ${OUTPUT_DIR}
caffe1_convert /share/models/caffe_original_batch_equal_1/resnet18 ${OUTPUT_DIR}
caffe1_convert /share/models/caffe_original_batch_equal_1/resnet50 ${OUTPUT_DIR}
caffe1_convert /share/models/caffe_original_batch_equal_1/shufflenet ${OUTPUT_DIR}
caffe1_convert /share/models/caffe_original_batch_equal_1/squeezenet ${OUTPUT_DIR}

function tf1_x_convert() {
    FILE_PATH=$1
    INPUT_ARRAY=$2
    OUTPUT_ARRAY=$3
    OUTPUT_DIR=$4
    EXTRA_ARGS=${@:5}

    FILE_NAME=$(basename "$FILE_PATH" .pb)
    tflite_convert --graph_def_file=$FILE_PATH \
        --input_arrays=$INPUT_ARRAY \
        --output_arrays=$OUTPUT_ARRAY \
        $EXTRA_ARGS --output_file=$OUTPUT_DIR/tf_$FILE_NAME.tflite
}

tf1_x_convert /share/models/tf_original/mnasnet/mnasnet-a1.pb Placeholder mnasnet-a1/mnas_net_model/mnas_head/dense/BiasAdd ${OUTPUT_DIR}
tf1_x_convert /share/models/tf_original/mobilenetv1/mobilenet_v1_1.0_224_frozen.pb input MobilenetV1/Predictions/Softmax ${OUTPUT_DIR}
tf1_x_convert /share/models/tf_original/mobilenetv2/mobilenet_v2_1.4_224_frozen.pb input MobilenetV2/Predictions/Softmax ${OUTPUT_DIR} "--input_shapes=1,224,224,3"
tf1_x_convert /share/models/tf_original/resnet_v1_101/resnet_v1_101.pb inputs resnet_v1_101/predictions/Softmax ${OUTPUT_DIR}
tf1_x_convert /share/models/tf_original/resnet_v2_101/resnet_v2_101.pb inputs resnet_v2_101/predictions/Softmax ${OUTPUT_DIR}
tf1_x_convert /share/models/tf_original/shufflenet/shufflenet.pb ToFloat classifier/BiasAdd ${OUTPUT_DIR}
tf1_x_convert /share/models/tf_original/squeezenet/squeezenet.pb images average_pooling2d/AvgPool ${OUTPUT_DIR}
