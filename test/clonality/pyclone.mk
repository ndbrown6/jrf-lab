include modules/Makefile.inc

LOGDIR ?= log/setup_pyclone.$(NOW)
PHONY += pyclone

pyclone : $(foreach pair,$(SAMPLE_PAIRS),pyclone/$(pair)/config.yaml) #$(foreach pair,$(SAMPLE_PAIRS),pyclone/$(pair)/report/report.tsv) $(foreach pair,$(SAMPLE_PAIRS),pyclone/$(pair)/report/histogram_ccf.pdf)

define make-pyclone
pyclone/$1_$2/config.yaml : summary/tsv/mutation_summary.tsv
	$$(call RUN, -s 16G -m 24G,"mkdir -p pyclone/$1_$2 && \
								mkdir -p pyclone/$1_$2/report && \
							    $(RSCRIPT) modules/test/clonality/tsvtopyclone.R --sample_name $1_$2")
							    
# pyclone/$1_$2/trace/alpha.tsv.bz2 : pyclone/$1_$2/config.yaml
#	$$(call RUN,-s 16G -m 24G -w 7200,"source /home/${USER}/share/usr/anaconda-envs/jrflab-modules-0.1.5/bin/activate /home/${USER}/share/usr/anaconda-envs/PyClone-0.13.1 && \
#							 		   PyClone run_analysis --config_file pyclone/$1_$2/config.yaml --seed 0")
#							 		  
#pyclone/$1_$2/pyclone.tsv : pyclone/$1_$2/trace/alpha.tsv.bz2
#	$$(call RUN,-s 16G -m 24G -w 7200,"source /home/${USER}/share/usr/anaconda-envs/jrflab-modules-0.1.5/bin/activate /home/${USER}/share/usr/anaconda-envs/PyClone-0.13.1 && \
#							 		   PyClone build_table --config_file pyclone/$1_$2/config.yaml --out_file pyclone/$1_$2/pyclone.tsv --max_cluster 10 --table_type old_style --burnin 50000")
#							 		   
#pyclone/$1_$2/report/ccf.pdf : pyclone/$1_$2/pyclone.tsv
#	$$(call RUN, -s 24G -m 48G,"mkdir -p pyclone/$1_$2 && \
#								mkdir -p pyclone/$1_$2/report && \
#							    $(RSCRIPT) modules/test/clonality/plotpyclone.R --sample_name $1_$2")
#							    
#pyclone/$1_$2/report/report.tsv : pyclone/$1_$2/pyclone.tsv
#	$$(call RUN, -s 24G -m 48G,"mkdir -p pyclone/$1_$2 && \
#								mkdir -p pyclone/$1_$2/report && \
#							    $(RSCRIPT) modules/test/clonality/reportpyclone.R --sample_name $1_$2")

endef
$(foreach pair,$(SAMPLE_PAIRS),\
		$(eval $(call make-pyclone,$(tumor.$(pair)),$(normal.$(pair)))))

.DELETE_ON_ERROR:
.SECONDARY:
.PHONY: $(PHONY)
