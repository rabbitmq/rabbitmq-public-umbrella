
define parent_requires_ezs
# parent is in $(1)
$(foreach EZ,$($(PACKAGE_DIR)_OUTPUT_EZS),$(call parent_requires_ez,$(1),$(EZ)))
endef

define parent_requires_ez
# parent is in $(1), ez is in $(2)
ifndef $(1)/$(DIST_DIR)/$(2)
$(1)/$(DIST_DIR)/$(2):=true
# the parent's beams depend on the child's ez
$($(1)_EBIN_BEAMS): $(1)/$(DIST_DIR)/$(2)-$($(PACKAGE_DIR)_VERSION).ez.stamp
# $$(info $($(1)_EBIN_BEAMS): $(1)/$(DIST_DIR)/$(2)-$($(PACKAGE_DIR)_VERSION).ez.stamp)
# the parent's internal deps depend on the child's ez
$(patsubst %,$(1)/$(DIST_DIR)/%-$($(PACKAGE_DIR)_VERSION).ez,$($(1)_INTERNAL_DEPS)): $(1)/$(DIST_DIR)/$(2)-$($(PACKAGE_DIR)_VERSION).ez.stamp
# $$(info $(patsubst %,$(1)/$(DIST_DIR)/%-$($(PACKAGE_DIR)_VERSION).ez,$($(1)_INTERNAL_DEPS)): $(1)/$(DIST_DIR)/$(2)-$($(PACKAGE_DIR)_VERSION).ez.stamp)
# $$(info $(1)/$(DIST_DIR)/$(2)-$($(PACKAGE_DIR)_VERSION).ez.stamp: $(PACKAGE_DIR)/$(DIST_DIR)/$(2)-$($(PACKAGE_DIR)_VERSION).ez)
$(1)/$(DIST_DIR)/$(2)-$($(PACKAGE_DIR)_VERSION).ez.stamp_CHILD_VERSION:=$($(PACKAGE_DIR)_VERSION)
$(1)/$(DIST_DIR)/$(2)-$($(PACKAGE_DIR)_VERSION).ez.stamp: $(PACKAGE_DIR)/$(DIST_DIR)/$(2)-$($(PACKAGE_DIR)_VERSION).ez | $(1)/$(DIST_DIR)
	rm -rf $(1)/$(DIST_DIR)/$(2)-$$($$@_CHILD_VERSION).ez $(1)/$(DIST_DIR)/$(2)-$$($$@_CHILD_VERSION)
	cp $$< $(1)/$(DIST_DIR)/
	cd $(1)/$(DIST_DIR)/ && unzip $(2)-$$($$@_CHILD_VERSION).ez
	touch $$@

endif
# form transitive closure so that ezs keep travelling upwards
$(foreach PARENT,$($(1)_PARENTS),$(eval $(call parent_requires_ezs,$(PARENT))))
endef

$(foreach PARENT,$($(PACKAGE_DIR)_PARENTS),$(eval $(call parent_requires_ezs,$(PARENT))))
