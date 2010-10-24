# This file is included as the last file to include at the end of
# parsing an constructing the entire Makefile. The sole purpose of
# this file is to enforce the dependencies between the different
# packages as per each package's DEPS variable.
#
# The PACKAGE_NAMES variable contains the name of every package that
# we have visited and thus is necessary to build. We iterate over
# these, and form the transitive closure, ensuring that an ancestor's
# BEAMS and INTERNAL_DEPS are dependent upon its descendants' EZS
# (both OUTPUT_EZS and INTERNAL_DEPS (of the descendant)). Thus:
#
#      A
#     / \
#    B   C
#     \ /
#      D
#      |
#      E
#
# A : B C D E
# B : D E
# C : D E
# D : E
# E :
#

define ancestor_requires_ez
# ancestor package_dir is in $(1).
# descendant package_dir is in $(2).
# descendant full ez path is in $(3)
# descendant full ez path transposed into ancestor is in $(4)

ifndef $(4)
$(4):=true

# the ancestor's beams depend on the child's ez in the ancestor's dist dir
# $$(info $($(1)_EBIN_BEAMS): $(4).stamp)
$($(1)_EBIN_BEAMS): $(4).stamp

# the ancestor's internal deps depend on the child's ez
$($(1)_INTERNAL_DEPS_PATHS): $(4).stamp

# $$(info $(4).stamp: $(3) | $(1)/$(DIST_DIR))
$(4).stamp: $(3) | $(1)/$(DIST_DIR)
	rm -rf $(4) $(patsubst %.ez,%,$(4)) $$@
	cp $$< $$(@D)
	cd $$(@D) && unzip $(notdir $(4))
	touch $$@
endif

endef

define ancestor_requires_descendant
# ancestor package_dir is in $(1). descendant package_dir is in $(2)
# $$(info $(1) : $(2))

# the ancestor's requires descendant's EZS
$(foreach EZ,$($(2)_OUTPUT_EZS_PATHS),$(call ancestor_requires_ez,$(1),$(2),$(EZ),$(patsubst $(2)/%,$(1)/%,$(EZ))))

# the ancestor's requires descendant's INTERNAL_DEPS
$(foreach EZ,$($(2)_INTERNAL_DEPS_PATHS),$(call ancestor_requires_ez,$(1),$(2),$(EZ),$(patsubst $(2)/%,$(1)/%,$(EZ))))

# form transitive closure - ancestor requires _all_ its descendants
$(call link,$(1),$(2))
endef

define link
# package_dir is in $(1)
$(foreach DEP,$($(2)_DEPS),$(eval $(call ancestor_requires_descendant,$(1),$($(DEP)_DIR))))
endef

$(foreach PACKAGE_NAME,$(PACKAGE_NAMES),$(eval $(call link,$($(PACKAGE_NAME)_DIR),$($(PACKAGE_NAME)_DIR))))
