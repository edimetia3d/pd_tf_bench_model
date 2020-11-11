#!/bin/bash

cd Dockerfiles
docker build ./ -t convert_to_tflite -f ToTFLite.Dockerfile
cd ..

docker run -it -u $UID --rm -v /share:/share -v $PWD:/workspace convert_to_tflite bash "/workspace/do_convert.sh"