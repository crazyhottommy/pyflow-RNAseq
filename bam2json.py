#!/usr/bin/env python3


import json
import os
import re
from os.path import join
import argparse
from collections import defaultdict

parser = argparse.ArgumentParser()
parser.add_argument("--bam_dir", help="Required. the FULL path to the fastq folder")
args = parser.parse_args()

assert args.bam_dir is not None, "please provide the path to the bam folder"


## default dictionary is quite useful!

FILES = defaultdict(list)

## build the dictionary with full path for each fastq.gz file
for root, dirs, files in os.walk(args.bam_dir):
	for file in files:
		if file.endswith("bam"):
			full_path = join(root, file)
			#R1 will be forward reads, R2 will be reverse reads
			m = re.search(r"(.+)\.bam$", file)
			if m:
				sample = m.group(1)
				FILES[sample].append(full_path)
				
print()
print ("total {} unique samples will be processed".format(len(FILES.keys())))
print ("------------------------------------------")
for sample in FILES.keys():
	print ("{sample}'s bam is {bam}".format(sample = sample, bam = "\t".join(FILES[sample])))
print ("------------------------------------------")
print("check the samples.json file for fastqs belong to each sample")
print()

js = json.dumps(FILES, indent = 4, sort_keys=True)
open('samples.json', 'w').writelines(js)


