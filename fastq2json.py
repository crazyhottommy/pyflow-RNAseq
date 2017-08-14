#!/usr/bin/env python3


import json
import os
import re
from os.path import join
import argparse
from collections import defaultdict

parser = argparse.ArgumentParser()
parser.add_argument("--fastq_dir", help="Required. the FULL path to the fastq folder")
args = parser.parse_args()

assert args.fastq_dir is not None, "please provide the path to the fastq folder"


## default dictionary is quite useful!

FILES = defaultdict(lambda: defaultdict(list))

## build the dictionary with full path for each fastq.gz file
for root, dirs, files in os.walk(args.fastq_dir):
	for file in files:
		if file.endswith("fastq.gz"):
			full_path = join(root, file)
			#R1 will be forward reads, R2 will be reverse reads
			m = re.search(r"(.+)_(R[12])_[0-9]{3,4}.fastq.gz", file)
			if m:
				sample = m.group(1)
				reads = m.group(2)  
				FILES[sample][reads].append(full_path)
				
print()
print ("total {} unique samples will be processed".format(len(FILES.keys())))
print ("------------------------------------------")
for sample in FILES.keys():
	for read in FILES[sample]:
		print ("{sample} {read} has {n} fastq".format(sample = sample, read = read, n = len(FILES[sample][read])))
print ("------------------------------------------")
print("check the samples.json file for fastqs belong to each sample")
print()

js = json.dumps(FILES, indent = 4, sort_keys=True)
open('samples.json', 'w').writelines(js)


