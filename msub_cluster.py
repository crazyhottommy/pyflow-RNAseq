#!/usr/bin/env python3

"""
Submit this clustering script for sbatch to snakemake with:
    snakemake -j 99 --debug --immediate-submit --cluster-config cluster.json --cluster 'msub_cluster.py {dependencies}'
"""

## In order to submit all the jobs to the moab queuing system, one needs to write a wrapper.
## This wrapper is inspired by Daniel Park https://github.com/broadinstitute/viral-ngs/blob/master/pipes/Broad_LSF/cluster-submitter.py
## I asked him questions on the snakemake google group and he kindly answered: https://groups.google.com/forum/#!topic/snakemake/1QelazgzilY

import sys
import re
import os
import errno
from snakemake.utils import read_job_properties

## snakemake will generate a jobscript containing all the (shell) commands from your Snakefile. 
## I think that's something baked into snakemake's code itself. It passes the jobscript as the last parameter.
## https://bitbucket.org/snakemake/snakemake/wiki/Documentation#markdown-header-job-properties

## make a directory for the logs from the cluster 
try: 
	os.makedirs("msub_log")
except OSError as exception:
	if exception.errno != errno.EEXIST:
		raise


jobscript = sys.argv[-1]
job_properties = read_job_properties(jobscript)

## the jobscript is something like snakejob.index_bam.23.sh
mo = re.match(r'(\S+)/snakejob\.\S+\.(\d+)\.sh', jobscript)
assert mo
sm_tmpdir, sm_jobid = mo.groups()

## set up jobname. 
jobname = "{rule}-{jobid}".format(rule = job_properties["rule"], jobid = sm_jobid)

## it is safer to use get method in case the key is not present
# the job_properties is a dictionary of dictonary. I set up job name in the Snake file under the params directive and associate the sample name with the 
# job

jobname_tag_sample = job_properties.get('params', {}). get('jobname')


if jobname_tag_sample:
	jobname = jobname + "-" + jobname_tag_sample
# access property defined in the cluster configuration file (Snakemake >=3.6.0), cluster.json
time = job_properties["cluster"]["time"]
cpu = job_properties["cluster"]["cpu"]
mem = job_properties["cluster"]["mem"]
nodes = job_properties["cluster"]["nodes"]
EmailNotice = job_properties["cluster"]["EmailNotice"]
email = job_properties["cluster"]["email"]

cmdline = 'msub -V -l nodes={nodes}:ppn={cpu} -l mem={mem} -N {jobname} -l walltime={time} -m {EmailNotice} -M {email} -e msub_log/ -o msub_log/'.format(nodes = nodes, cpu = cpu, jobname = jobname, mem = mem, time = time, EmailNotice = EmailNotice, email = email)

# figure out job dependencies, the last argument is the jobscript which is baked in snakemake
dependencies = set(sys.argv[1:-1])
if dependencies:
    cmdline += " -l depend=afterok:'{}'".format(":".join(dependencies))

# note the space
cmdline += " "

# the actual job
cmdline += jobscript

# remove the leading and trailing white space for the submitted jobid
cmdline += r" | tail -1 | sed 's/^[ \t]*//;s/[ \t]*$//' "

# call the command
os.system(cmdline)
