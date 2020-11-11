#!/usr/bin/python3

from os import listdir
from os.path import isfile, join,isdir
from parse import parse

def save_dict_to_file(out_dict,output_path):
    processed_model={}
    out_file = open(output_path, 'w') 
    for k1 in out_dict:
        if k1[0] in processed_model:
            continue
        arm_data=[0,0,0]
        arm64_data=[0,0,0]
        for k2,v2 in out_dict.items():
            if k1[0] == k2[0] and k2[1] == "arm":
                if k2[2] == "1":
                    arm_data[0]=v2
                if k2[2] == "2":
                    arm_data[1]=v2
                if k2[2] == "4":
                    arm_data[2]=v2
            if k1[0] == k2[0] and k2[1] == "arm64":
                if k2[2] == "1":
                    arm64_data[0]=v2
                if k2[2] == "2":
                    arm64_data[1]=v2
                if k2[2] == "4":
                    arm64_data[2]=v2
        processed_model[k1[0]]=1
        str_out="{} {} {}".format(k1[0],arm_data,arm64_data)
        print(str_out)
        str_out=str_out.replace("[","")
        str_out=str_out.replace("]","")
        str_out=str_out.replace(",","")
        out_file.write(str_out+"\n")
    out_file.close()

def process_pdlite(dir_path:str,output_path:str):
    out_dict={}
    for f in listdir(dir_path):
        if f.find("profile") != -1:
            continue
        model_name=f[0:f.find("_arm")]
        arch="arm"
        if f.find("_arm64") != -1:
            arch="arm64"
        thread_num=f[-5]
        
        loop_count="-1"
        latency_ms="-1"
        file1 = open(dir_path+"/"+f, 'r') 
        for line in file1.readlines():           
            pos=line.find("benchmark loops")
            if pos != -1:
                parse_out=parse("benchmark loops {} times. avg time: {} ms",line)
                loop_count=parse_out[0]
                latency_ms=parse_out[1]
        out_dict[(model_name,arch,thread_num)]=float(latency_ms)
        file1.close()
    
    save_dict_to_file(out_dict,output_path)

def process_tflite(dir_path:str,output_path:str):
    out_dict={}
    for f in listdir(dir_path):
        if f.find("profile") != -1:
            continue
        model_name=f[0:f.find("_arm")]
        arch="arm"
        if f.find("_arm64") != -1:
            arch="arm64"
        thread_num=f[-5]
        
        loop_count="-1"
        latency_ms="-1"
        file1 = open(dir_path+"/"+f, 'r') 
        for line in file1.readlines():           
            pos=line.find("Inference timings in us:")
            if pos != -1:
                parse_out=parse("Inference timings in us: Init: {}, First inference: {}, Warmup (avg): {}, Inference (avg): {}",line)
                latency_ms=parse_out[3]
        out_dict[(model_name,arch,thread_num)]=float(latency_ms)/1000
        file1.close()
    
    save_dict_to_file(out_dict,output_path)

for f in listdir("./"):
    if isdir(f+"/pdlite"):
        print("========pdlite-{}=======".format(f))
        process_pdlite(f+"/pdlite",f+"/pdlite.txt")

for f in listdir("./"):
    if isdir(f+"/tflite"):
        print("========tflite-{}=======".format(f))
        process_tflite(f+"/tflite",f+"/tflite.txt")