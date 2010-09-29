# This file is included every time we visit a package. It sets up
# reverse pointers to our parents (thus relies on the
# $(PACKAGE_DIR)_PARENTS variables that deps.mk creates) for our
# OUTPUT_EZS.
#
# Thus if foo depends on bar, we start in foo, but we don't know what
# the OUTPUT_EZS of bar are going to be. So deps.mk sets
# bar_PARENTS:=foo, and then when we visit foo and come in here, we
# now make sure that foo's EBIN_BEAMS depend on our (bar's)
# OUTPUT_EZS.
#
# We have to afford the possibility of visiting this multiple times. E.g.
# foo -> bar; foo -> baz; bar -> qux; baz -> qux
# The first time we visit qux, we will only have one parent (either
# bar or baz). The second time we visit it, we will know of both
# parents and can thus ensure we get all the correct dependencies.
#
# We start at the bottom of the file, and say that for each parent we
# know about, we're going to make the parent depend on all of our
# OUTPUT_EZS. That amounts to making the parent's BEAMS and
# INTERNAL_DEPS depend on the parent's local copy of our (the child's)
# OUTPUT_EZS.

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
