#! /bin/bash

## make a folder for bsub_log if not exist
folder="sbatch_log"


if [ ! -d "$folder" ]; then
    mkdir -p "$folder"
fi

snakemake --jobs 99999 \
        -k \
    --latency-wait 240 \
    --cluster-config cluster.json \
    --cluster "sbatch --partition {cluster.p} --mem {cluster.mem} -N {cluster.N} -n {cluster.n} --time {cluster.time} --job-name {cluster.name} --output {$
    "$@"

