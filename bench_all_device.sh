#!/bin/bash

adb devices | while read line
do
    if [ ! "$line" = "" ] && [ `echo $line | awk '{print $2}'` = "device" ]
    then
        device=`echo $line | awk '{print $1}'`
        if [ "$device" != "6H19243D3808BA60" ]; then
            mkdir -p $device/pdlite
            mkdir -p $device/tflite
            tmux new-session -d -s ${device}_bench "./bench_all_pd_model.sh $device release pd_model $device/pdlite && ./bench_all_tf_model.sh $device release tf_model $device/tflite"
            echo ${device}_bench tmux session created
        fi
    
    fi
done