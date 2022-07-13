include innovation-lab/Makefile.inc
include innovation-lab/config/gatk.inc
include innovation-lab/config/align.inc

LOGDIR ?= log/bwa_split.$(NOW)


bwa_split : $(foreach sample,$(SAMPLES),bwamem/$(sample)/$(sample)_R1.fastq.gz) \
	    $(foreach sample,$(SAMPLES),bwamem/$(sample)/$(sample)_R2.fastq.gz) \
	    $(foreach sample,$(SAMPLES),bwamem/$(sample)/taskcomplete.txt)

N = 100
OUTPUT = ""
for i in $(seq 1 $N); do cmdline = $OUTPUT" -o $i.fastq.gz"; done

BWAMEM_THREADS = 12
BWAMEM_MEM_PER_THREAD = 2G

SAMTOOLS_THREADS = 8
SAMTOOLS_MEM_THREAD = 2G

GATK_THREADS = 8
GATK_MEM_THREAD = 2G

define merge-fastq
bwamem/$1/$1_R1.fastq.gz : $$(foreach split,$2,$$(word 1, $$(fq.$$(split))))
	$$(call RUN,-c -n 1 -s 4G -m 6G -w 72:00:00,"zcat $$(^) | gzip -c > $$(@)")
	
bwamem/$1/$1_R2.fastq.gz : $$(foreach split,$2,$$(word 2, $$(fq.$$(split))))
	$$(call RUN,-c -n 1 -s 4G -m 6G -w 72:00:00,"zcat $$(^) | gzip -c > $$(@)")
endef
$(foreach sample,$(SAMPLES),\
		$(eval $(call merge-fastq,$(sample),$(split.$(sample)))))
		

define split-fastq
bwamem/$1/taskcomplete.txt : bwamem/$1/$1_R1.fastq.gz bwamem/$1/$1_R2.fastq.gz
	$$(call RUN,-c -n 1 -s 8G -m 16G -v $(FASTQ_SPLITTER_ENV),"set -o pipefail && \
								   fastqsplitter \
								   -i $1_R1.fastq.gz \
								   $(OUTPUT) && \
								   touch taskcomplete.txt")

endef
$(foreach sample,$(SAMPLES),\
	$(eval $(call split-fastq,$(sample))))


..DUMMY := $(shell mkdir -p version; \
	     $(BWA) &> version/tmp.txt; \
	     head -3 version/tmp.txt | tail -2 > version/bwa_split.txt; \
	     rm version/tmp.txt; \
	     $(SAMTOOLS) --version >> version/bwa_split.txt; \
	     echo "gatk3" >> version/bwa_split.txt; \
	     $(GATK) --version >> version/bwa_split.txt; \
	     echo "picard" >> version/bwa_split.txt; \
	     $(PICARD) MarkDuplicates --version &>> version/bwa_split.txt)
.SECONDARY:
.DELETE_ON_ERROR:
.PHONY: bwa_split
