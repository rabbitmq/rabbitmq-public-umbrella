
define parent_requires_ezs
# parent is in $(1)
$(foreach EZ,$($(PACKAGE_DIR)_OUTPUT_EZS),$(call parent_requires_ez,$(1),$(EZ)))
endef

define parent_requires_ez
# parent is in $(1), ez is in $(2)
ifndef $(1)/$(DIST_DIR)/$(2)
$(1)/$(DIST_DIR)/$(2):=true
$($(1)_EBIN_BEAMS): $(1)/$(DIST_DIR)/$(2).stamp
# $$(info $($(1)_EBIN_BEAMS): $(1)/$(DIST_DIR)/$(2).stamp)
# $$(info $(1)/$(DIST_DIR)/$(2).stamp: $(PACKAGE_DIR)/$(DIST_DIR)/$(2))
$(1)/$(DIST_DIR)/$(2).stamp: $(PACKAGE_DIR)/$(DIST_DIR)/$(2) | $(1)/$(DIST_DIR)
	rm -rf $(1)/$(DIST_DIR)/$(2) $(1)/$(DIST_DIR)/$(basename $(2))
	cp $$< $(1)/$(DIST_DIR)/
	cd $(1)/$(DIST_DIR)/ && unzip $(2)
	touch $$@

# $$(info $(1)/$(DIST_DIR)/$(2) : $(PACKAGE_DIR)/$(DIST_DIR)/$(2))
endif
# form transitive closure so that ezs keep travelling upwards
$(foreach PARENT,$($(1)_PARENTS),$(eval $(call parent_requires_ezs,$(PARENT))))
endef

$(foreach PARENT,$($(PACKAGE_DIR)_PARENTS),$(eval $(call parent_requires_ezs,$(PARENT))))
