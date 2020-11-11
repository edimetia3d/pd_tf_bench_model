FROM continuumio/miniconda3
RUN pip install -i https://mirrors.163.com/pypi/simple/ pip -U
RUN pip config set global.index-url https://mirrors.163.com/pypi/simple/

RUN pip install tensorflow==1.15.2
RUN pip install mmdnn
# NOTE: onnx and onnx-tf's version must be match
RUN conda install -y -c conda-forge onnx=1.6.0
RUN apt-get update;apt-get install unzip -y

# RUN cd /opt; \
#     wget https://github.com/onnx/onnx-tensorflow/archive/v1.6.0.zip && \
#     unzip v1.6.0.zip && \
#     cd onnx-tensorflow-1.6.0 && \
#     pip install -e . && \
#     cd ..;rm v1.6.0.zip; \
#     cd /
# RUN pip install tensorflow-addons

RUN cd /opt; \
    wget https://github.com/onnx/onnx-tensorflow/archive/tf-1.x.zip && \
    unzip tf-1.x.zip && \
    cd onnx-tensorflow-tf-1.x && \
    pip install -e . && \
    cd ..;rm tf-1.x.zip; \
    cd /
