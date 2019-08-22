include modules/Makefile.inc
include modules/genome_inc/b37.inc

LOGDIR ?= log/interval_metrics.$(NOW)
PHONY += metrics metrics/standard metrics/unfiltered metrics/simplex metrics/duplex

POOL_A_TARGET_FILE ?= $(HOME)/share/reference/target_panels/MSK-ACCESS-v1_0-probe-A.sorted.list
POOL_B_TARGET_FILE ?= $(HOME)/share/reference/target_panels/MSK-ACCESS-v1_0-probe-B.sorted.list
WALTZ_MIN_MAPQ ?= 20

interval_metrics : $(foreach sample,$(SAMPLES),metrics/standard/$(sample).idx_stats.txt) \
				   $(foreach sample,$(SAMPLES),metrics/standard/$(sample).aln_metrics.txt) \
				   $(foreach sample,$(SAMPLES),metrics/standard/$(sample).insert_metrics.txt) \
				   $(foreach sample,$(SAMPLES),metrics/standard/$(sample).oxog_metrics.txt) \
				   $(foreach sample,$(SAMPLES),metrics/standard/$(sample).probe-A.hs_metrics.txt)

define picard-metrics
metrics/standard/$1.idx_stats.txt : bam/$1-standard.bam
	$$(call RUN, -c -n 1 -s 6G -m 12G,"java -Djava.io.tmpdir=$(TMPDIR) -Xms2G -Xmx8G -jar $$(PICARD_JAR) BamIndexStats \
									   I=$$(<) \
									   TMP_DIR=$(TMPDIR) \
									   > $$(@)")
									   
metrics/standard/$1.aln_metrics.txt : bam/$1-standard.bam
	$$(call RUN, -c -n 1 -s 6G -m 12G,"java -Djava.io.tmpdir=$(TMPDIR) -Xms2G -Xmx8G -jar $$(PICARD_JAR) CollectAlignmentSummaryMetrics \
									   R=$(REF_FASTA) \
									   I=$$(<) \
									   O=$$(@) \
									   TMP_DIR=$(TMPDIR)")

metrics/standard/$1.insert_metrics.txt : bam/$1-standard.bam
	$$(call RUN, -c -n 1 -s 6G -m 12G,"java -Djava.io.tmpdir=$(TMPDIR) -Xms2G -Xmx8G -jar $$(PICARD_JAR) CollectInsertSizeMetrics \
									   I=$$(<) \
									   O=$$(@) \
									   H=metrics/standard/$1.insert_metrics.pdf \
									   M=0.5 \
									   TMP_DIR=$(TMPDIR)")
												
metrics/standard/$1.oxog_metrics.txt : bam/$1-standard.bam
	$$(call RUN, -c -n 1 -s 6G -m 12G,"java -Djava.io.tmpdir=$(TMPDIR) -Xms2G -Xmx8G -jar $$(PICARD_JAR) CollectOxoGMetrics \
									   R=$(REF_FASTA) \
									   I=$$(<) \
									   O=$$(@) \
									   TMP_DIR=$(TMPDIR)")

metrics/standard/$1.probe-A.hs_metrics.txt : bam/$1-standard.bam
	$$(call RUN, -c -n 1 -s 6G -m 12G,"java -Djava.io.tmpdir=$(TMPDIR) -Xms2G -Xmx8G -jar $$(PICARD_JAR) CollectHsMetrics \
									   R=$(REF_FASTA) \
									   I=$$(<) \
									   O=$$(@) \
									   BAIT_INTERVALS=$(POOL_A_TARGET_FILE) \
									   TARGET_INTERVALS=$(POOL_A_TARGET_FILE) \
									   MINIMUM_MAPPING_QUALITY=$(WALTZ_MIN_MAPQ) \
									   TMP_DIR=$(TMPDIR)")
												
#metrics/standard/$1.pool-B.hs_metrics.txt : bam/%-standard.bam
#	$$(call RUN, -c -n 1 -s 12G -m 18G -w 1440,"java -Djava.io.tmpdir=$(TMPDIR) -Xms2G -Xmx16G -jar $$(PICARD_JAR) CollectHsMetrics \
#												R=$(REF_FASTA) \
#												I=$$(<) \
#												O=$$(@) \
#												BAIT_INTERVALS=$(POOL_B_TARGET_FILE) \
#												TARGET_INTERVALS=$(POOL_B_TARGET_FILE) \
#												TMP_DIR=$(TMPDIR)")
#
endef
$(foreach sample,$(SAMPLES),\
		$(eval $(call picard-metrics,$(sample))))


.DELETE_ON_ERROR:
.SECONDARY:
.PHONY: $(PHONY)
