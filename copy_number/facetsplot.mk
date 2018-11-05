include modules/Makefile.inc

LOGDIR ?= log/facets_plot.$(NOW)
PHONY += facets facets/plots

facets_plot : $(foreach pair,$(TUMOR_PAIRS),facets/plots/$(pair).pdf)

define facets-plot
facets/plots/$1_$2.pdf : facets/cncf/$1_$2.Rdata
	$$(call RUN,-c -v ~/share/usr/anaconda-envs/ascat -s 4G -m 6G,"$(RSCRIPT) modules/copy_number/facetsplot.R --in_file $$(<) --out_file facets/plots/$$(*).pdf")
endef
 $(foreach pair,$(TUMOR_PAIRS),\
		$(eval $(call facets-plot,$(pair))))
				
.PHONY: $(PHONY)
