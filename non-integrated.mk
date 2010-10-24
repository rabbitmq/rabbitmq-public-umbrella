# This file is the non-integrated equivalent of targets.mk. It sets up
# the recursive make invocations (which are necessarily .PHONY) for
# non-integrated packages. The actual settings for such packages are
# found in global.mk.
#
# link.mk is still used to set up the links to the parents of such
# non-integrated children, so that they know what .ezs to copy up and
# unpack.

ifdef PACKAGE_DIR
ifndef $(PACKAGE_DIR)_TARGETS
$(PACKAGE_DIR)_TARGETS:=true

define make_in_non_intergrated
.PHONY: $(1)
$(1): $(2)
endef

$(PACKAGE_DIR)_OUTPUT_EZS_PATHS:=$(patsubst %,$(PACKAGE_DIR)/$(DIST_DIR)/%-$($(PACKAGE_DIR)_VERSION).ez,$($(PACKAGE_DIR)_OUTPUT_EZS))

# the output ezs are just dependent on the package_dir itself (though PHONY)
$(foreach EZ,$($(PACKAGE_DIR)_OUTPUT_EZS_PATHS),$(eval $(call make_in_non_intergrated,$(EZ),$(PACKAGE_DIR))))

.PHONY: $(PACKAGE_DIR)/clean
clean:: $(PACKAGE_DIR)/clean
$(PACKAGE_DIR)/clean:
	$(MAKE) -C $(@D) clean

.PHONY: $(PACKAGE_DIR)
$(PACKAGE_DIR): $(PACKAGE_DIR)/Makefile
	$(MAKE) -C $@ VERSION=$($@_VERSION)

endif

endif
