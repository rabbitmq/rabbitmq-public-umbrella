ifdef PACKAGE_DIR
ifndef $(PACKAGE_DIR)_TARGETS
$(PACKAGE_DIR)_TARGETS:=true

define make_in_non_intergrated
.PHONY: $(1)
$(1): $(2)
endef

# the output ezs are just dependent on the package_dir itself (though PHONY)
$(foreach EZ,$($(PACKAGE_DIR)_OUTPUT_EZS),$(eval $(call make_in_non_intergrated,$(PACKAGE_DIR)/$(DIST_DIR)/$(EZ)-$(VERSION).ez,$(PACKAGE_DIR))))

.PHONY: $(PACKAGE_DIR)/clean
clean:: $(PACKAGE_DIR)/clean
$(PACKAGE_DIR)/clean:
	$(MAKE) -C $(@D) clean

.PHONY: $(PACKAGE_DIR)
$(PACKAGE_DIR):
	$(MAKE) -C $@ -j

endif

include ../common.mk

endif
