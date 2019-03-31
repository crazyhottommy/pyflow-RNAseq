shell.prefix("set -eo pipefail; echo BEGIN at $(date); ")
shell.suffix("; exitstat=$?; echo END at $(date); echo exit status was $exitstat; exit $exitstat")

configfile: "config.yaml"

FILES = json.load(open(config['SAMPLES_JSON']))

CLUSTER = json.load(open(config['CLUSTER_JSON']))

SAMPLES = sorted(FILES.keys())

MYGTF = config["MYGTF"]

STARINDEX = config["STARINDEX"]

TARGETS = []

## constructe the target if the inputs are fastqs
if config["from_fastq"]:
	ALL_BAM = expand("01bam_fq/{sample}Aligned.out.bam", sample = SAMPLES)
	ALL_SORTED_BAM = expand("02sortBam_fq/{sample}.sorted.bam", sample = SAMPLES)
	ALL_BAM_INDEX = expand("02sortBam_fq/{sample}.sorted.bam.bai", sample = SAMPLES)
	TARGETS.extend(ALL_BAM)
	TARGETS.extend(ALL_SORTED_BAM)
	TARGETS.extend(ALL_BAM_INDEX)
	
	if config["htseq"]:
		ALL_CNT = expand("03htseq_fq/{sample}_htseq.cnt", sample = SAMPLES)
		TARGETS.extend(ALL_CNT)

	if config["featureCount"]:
		ALL_featureCount = expand("04featureCount_fq/{sample}_featureCount.txt", sample = SAMPLES)
		TARGETS.extend(ALL_featureCount)

	ALL_BIGWIG = expand("05bigwig_fq/{sample}.bw", sample = SAMPLES)
	TARGETS.extend(ALL_BIGWIG)


## construct the target if the inputs are bams

if not config["from_fastq"]:
	if config["htseq"]:
		ALL_CNT = expand("01htseq_bam/{sample}_htseq.cnt", sample = SAMPLES)
		TARGETS.extend(ALL_CNT)

	if config["featureCount"]:
		ALL_featureCount = expand("02featureCount_bam/{sample}_featureCount.txt", sample = SAMPLES)
		TARGETS.extend(ALL_featureCount)

	ALL_BIGWIG = expand("03bigwig_bam/{sample}.bw", sample = SAMPLES)
	TARGETS.extend(ALL_BIGWIG)

localrules: all
# localrules will let the rule run locally rather than submitting to cluster
# computing nodes, this is for very small jobs

rule all:
	input: TARGETS

rule STAR_fq:
	input: 
		r1 = lambda wildcards: FILES[wildcards.sample]['R1'],
		r2 = lambda wildcards: FILES[wildcards.sample]['R2']
	output: "01bam_fq/{sample}Aligned.out.bam"
	log: "00log/{sample}_STAR_align.log"
	params: 
		jobname = "{sample}",
		outprefix = "01bam_fq/{sample}"
	threads: 5
	message: "aligning {input} using STAR: {threads} threads"
	shell:
		"""
		STAR --runMode alignReads \
		--runThreadN 5 \
		--bamRemoveDuplicatesType UniqueIdentical \
		--genomeDir {STARINDEX} \
		--genomeLoad NoSharedMemory \
		--readFilesIn {input.r1} {input.r2} \
		--readFilesCommand zcat \
		--twopassMode Basic \
		--runRNGseed 777 \
		--outFilterType Normal \
		--outFilterMultimapNmax 20 \
		--outFilterMismatchNmax 10 \
		--outFilterMultimapScoreRange 1 \
		--outFilterMatchNminOverLread 0.33 \
		--outFilterScoreMinOverLread 0.33 \
		--outReadsUnmapped None \
		--alignIntronMin 20 \
		--alignIntronMax 500000 \
		--alignMatesGapMax 1000000 \
		--alignSJoverhangMin 8 \
		--alignSJstitchMismatchNmax 5 -1 5 5 \
		--sjdbScore 2 \
		--alignSJDBoverhangMin 1 \
		--sjdbOverhang 100 \
		--chimSegmentMin 20 \
		--chimJunctionOverhangMin 20 \
		--chimSegmentReadGapMax 3 \
		--quantMode GeneCounts \
		--outMultimapperOrder Random \
		--outSAMstrandField intronMotif \
		--outSAMattributes All \
		--outSAMunmapped Within KeepPairs \
		--outSAMtype BAM Unsorted \
		--limitBAMsortRAM 30000000000 \
		--outSAMmode Full \
		--outSAMheaderHD @HD VN:1.4 \
		--outFileNamePrefix {params.outprefix} 2> {log}
		"""

rule HTSeq_fq:
	input: "01bam_fq/{sample}Aligned.out.bam"
	output: "03htseq_fq/{sample}_htseq.cnt"
	log: "00log/{sample}_htseq_count.log"
	params: 
		jobname = "{sample}"
	threads: 1
	message: "htseq-count {input} : {threads} threads"
	shell:
		"""
		source activate root
		htseq-count -m intersection-nonempty --stranded=no --idattr gene_id -r name -f bam {input} {MYGTF} > {output} 2> {log}

		"""

rule featureCount_fq:
	input: "01bam_fq/{sample}Aligned.out.bam"
	output: "04featureCount_fq/{sample}_featureCount.txt"
	log: "00log/{sample}_featureCount.log"
	params:
		jobname = "{sample}"
	threads: 5
	message: "feature-count {input} : {threads} threads"
	shell:
		"""
		# -p for paried-end, counting fragments rather reads
		featureCounts -T 5 -p -t exon -g gene_id -a {MYGTF} -o {output} {input} 2> {log}

		"""
rule sortBam_fq:
	input: "01bam_fq/{sample}Aligned.out.bam"
	output: "02sortBam_fq/{sample}.sorted.bam"
	log: "00log/{sample}_sortbam.log"
	params:
		jobname = "{sample}"
	threads: 5
	message: "sorting {input} : {threads} threads"
	shell:
		"""
		samtools sort -m 2G -@ 5 -T {output}.tmp -o {output} {input} 2> {log}

		"""

rule indexBam_fq:
	input: "02sortBam_fq/{sample}.sorted.bam"
	output: "02sortBam_fq/{sample}.sorted.bam.bai"
	log: "00log/{sample}_index_bam.log"
	params: 
		jobname = "{sample}"
	threads: 1
	message: "indexing {input} : {threads} threads"
	shell:
		"""
		samtools index {input}
		"""
	

rule make_bigwig_fq:
	input: "02sortBam_fq/{sample}.sorted.bam", "02sortBam_fq/{sample}.sorted.bam.bai"
	output: "05bigwig_fq/{sample}.bw"
	log: "00log/{sample}_bigwig.log"
	params:
		jobname = "{sample}"
	threads: 5
	message: "making bigwig {input} : {threads} threads"
	shell:
		"""
		source activate root
		bamCoverage -b {input[0]} --skipNonCoveredRegions --normalizeUsingRPKM --binSize 20 --smoothLength 100 -p 5  -o {output} 2> {log}

		"""

rule HTseq_bam:
	input: lambda wildcards: FILES[wildcards.sample]
	output: "01htseq_bam/{sample}_htseq.cnt"
	log: "00log/{sample}_htseq_count.log"
	params: 
		jobname = "{sample}"
	threads: 1
	message: "htseq-count {input} : {threads} threads"
	shell:
		"""
		source activate root
		htseq-count -m intersection-nonempty --stranded=no --idattr gene_id -r name -f bam {input} {MYGTF} > {output} 2> {log}

		"""
rule featureCount_bam:
	input: lambda wildcards: FILES[wildcards.sample]
	output: "02featureCount_bam/{sample}_featureCount.txt"
	log: "00log/{sample}_featureCount.log"
	params: 
		jobname = "{sample}"
	threads: 5
	message: "feature-count {input} : {threads} threads"
	shell:
		"""
		# -p for paried-end, counting fragments rather reads
		featureCounts -T 5 -p -t exon  -g gene_id -a {MYGTF} -o {output} {input} 2> {log}

		"""
	
rule make_bigwig_bam:
	input: lambda wildcards: FILES[wildcards.sample]
	output: "03bigwig_bam/{sample}.bw"
	log: "00log/{sample}_bigwig.log"
	params:
		jobname = "{sample}"
	threads: 5
	message: "making bigwig {input} : {threads} threads"
	shell:
		"""
		source activate root
		bamCoverage -b {input} --skipNonCoveredRegions --normalizeUsing RPKM --binSize 20 --smoothLength 100 -p 5  -o {output} 2> {log}

		"""