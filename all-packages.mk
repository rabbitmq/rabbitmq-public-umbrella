UMBRELLA_BASE_DIR:=.

include common.mk

# Pull in all the packages
$(foreach PACKAGE_MK,$(wildcard */package.mk),$(eval $(call do_package,$(call canonical_path,$(patsubst %/,%,$(dir $(PACKAGE_MK)))))))
