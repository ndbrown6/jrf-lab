# annotations that have pre-req annotations and are run last or should be run after the 2nd round of filtering

PROVEAN_SCRIPT = $(HOME)/share/usr/bin/provean.sh
CLASSIFY_PATHOGENICITY = python modules/vcf_tools/classify_pathogenicity_vcf.py
CLASSIFY_PATHOGENICITY_OPTS = --provean_script $(PROVEAN_SCRIPT) --qsub_script modules/scripts/qsub.pl --num_provean_threads 5 --mem_per_thread 1.5G 
vcf/%.pathogen.vcf : vcf/%.vcf
	$(INIT) $(call CHECK_VCF,$(CLASSIFY_PATHOGENICITY) $(CLASSIFY_PATHOGENICITY_OPTS) $< > $@ 2> $(LOG))

MUTATION_TASTER = $(PYTHON) modules/vcf_tools/mutation_taster_vcf.py
vcf/%.mut_taste.vcf : vcf/%.vcf
	$(INIT) $(MUTATION_TASTER) $< > $@ 2> $(LOG)

PROVEAN = $(RSCRIPT) modules/vcf_tools/proveanVcf.R
AA_TABLE = $(HOME)/share/reference/aa_table.tsv

PROVEAN_OPTS = --genome $(REF) --aaTable $(AA_TABLE) --ensemblTxdb $(ENSEMBL_TXDB) --mysqlHost $(EMBL_MYSQLDB_HOST) \
			   --mysqlPort $(EMBL_MYSQLDB_PORT) --mysqlUser $(EMBL_MYSQLDB_USER) \
               $(if $(EMBL_MYSQLDB_PW),--mysqlPassword $(EMBL_MYSQLDB_PW)) \
			   --mysqlDb $(EMBL_MYSQLDB_DB) --numThreads 8 --memPerThread 1G --queue $(QUEUE) --qsubPriority $(QSUB_PRIORITY)

vcf/%.provean.vcf : vcf/%.vcf
	$(call LSCRIPT_MEM,8G,10G,"$(PROVEAN) $(PROVEAN_OPTS) --outFile $@ $<")

CHASM = $(RSCRIPT) modules/vcf_tools/chasmVcf.R 
CHASM_DIR = $(HOME)/share/usr/CHASM-3.0/CHASM
SNVBOX_DIR = $(PWD)/modules/external/SNVBox
CHASM_CLASSIFIER ?= BRCA
vcf/%.chasm.vcf : vcf/%.vcf
	$(call CHECK_VCF,$(call LSCRIPT_CHECK_MEM,8G,17G,"cp $(SNVBOX_CONF) $(SNVBOX_DIR)/snv_box.conf && $(CHASM) --genome $(REF) --classifier $(subst $( ),$(,),$(CHASM_CLASSIFIER)) --chasmDir $(CHASM_DIR) --snvBoxDir $(SNVBOX_DIR) --outFile $@ $<"))

FATHMM = $(MY_RSCRIPT) modules/vcf_tools/fathmmVcf.R 
FATHMM_DIR = $(PWD)/modules/external/fathmm
FATHMM_OPTS = --genome $(REF) --ensemblTxdb $(ENSEMBL_TXDB) --ref $(REF_FASTA) \
			  --fathmmDir $(FATHMM_DIR) --fathmmConfig $(FATHMM_CONF) \
			  --mysqlHost $(EMBL_MYSQLDB_HOST) --mysqlPort $(EMBL_MYSQLDB_PORT) --mysqlUser $(EMBL_MYSQLDB_USER) \
              $(if $(EMBL_MYSQLDB_PW),--mysqlPassword $(EMBL_MYSQLDB_PW)) --mysqlDb $(EMBL_MYSQLDB_DB)

vcf/%.fathmm.vcf : vcf/%.vcf
	$(call CHECK_VCF,$(call LSCRIPT_CHECK_MEM,8G,10G,"$(FATHMM) $(FATHMM_OPTS) --outFile $@ $<"))


define hrun-tumor-normal
vcf/$1_$2.%.hrun.vcf : vcf/$1_$2.%.vcf bam/$1.bam bam/$2.bam bam/$1.bai bam/$2.bai
	$$(call LSCRIPT_CHECK_PARALLEL_MEM,4,2G,3G,"$$(call GATK_MEM,8G) -T VariantAnnotator -nt 4 -R $$(REF_FASTA) -A HomopolymerRun --dbsnp $$(DBSNP) $$(foreach bam,$$(filter %.bam,$$^),-I $$(bam) ) -V $$< -L $$< -o $$@")
endef
$(foreach pair,$(SAMPLE_PAIRS),$(eval $(call hrun-tumor-normal,$(tumor.$(pair)),$(normal.$(pair)))))

define hrun-sample
vcf/$1.%.hrun.vcf : vcf/$1.%.vcf bam/$1.bam bam/$1.bai
	$$(call LSCRIPT_CHECK_PARALLEL_MEM,4,2G,3G,"$$(call GATK_MEM,8G) -T VariantAnnotator -nt 4 -R $$(REF_FASTA) -L $$< -A HomopolymerRun --dbsnp $$(DBSNP) $$(foreach bam,$$(filter %.bam,$$^),-I $$(bam) ) -V $$< -o $$@")
endef
$(foreach sample,$(SAMPLES),$(eval $(call hrun-sample,$(sample))))

# run snp sift to annotated with dbnsfp
vcf/%.nsfp.vcf : vcf/%.vcf vcf/%.vcf.idx
	$(call CHECK_VCF,$(call LSCRIPT_CHECK_MEM,9G,12G,"$(call SNP_SIFT_MEM,8G) dbnsfp $(SNP_SIFT_OPTS) -f $(subst $( ),$(,),$(NSFP_FIELDS)) -db $(DB_NSFP) $< | sed '/^##INFO=<ID=dbNSFP/ s/Character/String/; /^##INFO=<ID=dbNSFP_clinvar_rs/ s/Integer/String/;' > $@"))

ANNOTATE_FACETS_VCF = $(RSCRIPT) modules/copy_number/annotateFacets2Vcf.R
define annotate-facets-pair
vcf/$1.%.facets.vcf : vcf/$1.%.vcf facets/cncf/$1.cncf.txt
	$$(call CHECK_VCF,$$(call LSCRIPT_MEM,4G,6G,"$$(ANNOTATE_FACETS_VCF) --facetsFile $$(<<) --outFile $$@ $$<"))
endef
$(foreach pair,$(SAMPLE_PAIRS),$(eval $(call annotate-facets-pair,$(pair))))

include modules/copy_number/titan.inc
define titan-pair
vcf/$1.%.titan.vcf : vcf/$1.%.vcf titan/optclust_results_w$(TITAN_WINDOW_SIZE)_p$(DEFAULT_PLOIDY_PRIOR)/$1.titan_seg.txt
	$$(call LSCRIPT_MEM,4G,6G,"$$(ANNOTATE_TITAN_LOH_VCF) --titanSeg $$(<<) --outFile $$@ $$<")
endef
$(foreach pair,$(SAMPLE_PAIRS),$(eval $(call titan-pair,$(pair))))
