# The purpose of this file is to drive the main recursive inclusion of
# Makefiles based on the current package's dependencies. It sets up
# the PACKAGE_DIR and PACKAGE_NAME variables before recursive
# inclusion, as well as setting up reverse pointers from the child
# back to the parent. These are required for correct dependencies, and
# used by common.mk.
#
# It also checks to see if the dependency points to a non-integrated
# target and if so then treats the dependency specially.
#
# The last thing that occurs prior to recursion into a child is the
# inclusion of targets.mk (or, if the child is non-integrated, the
# inclusion of non-integrated as the recursive step (i.e. no real
# recursion in this case)).

define package_deps
# child abspath is in $(1). $(PACKAGE_DIR) is the parent package at
# this point.

# Set up a pointer from the child back to its parents
$(1)_PARENTS:=$(PACKAGE_DIR) $($(1)_PARENTS)
#$$(info $(1) parents are $$($(1)_PARENTS))
endef

define package_recurse
# child abspath is in $(1). Child name is in $(2)
PACKAGE_DIR:=$(1)
PACKAGE_NAME:=$(2)
ifdef $(strip $(1))_VISITED
include ../common.mk
else
$(strip $(1))_VISITED:=true
ifeq "$(filter $(notdir $(strip $(1))),$(NON_INTEGRATED))" ""
$(foreach VAR,$(VARS),$(eval $(VAR):=undefined))
include $(strip $(1))/Makefile
else
include ../non-integrated.mk
endif
endif
endef

ifdef BASE_CASE_DONE
include ../targets.mk
$(foreach DEP,$($(PACKAGE_DIR)_DEPS),$(eval $(call package_deps,$(abspath $(CURDIR)/../$(strip $(DEP))))))
$(foreach DEP,$($(PACKAGE_DIR)_DEPS),$(eval $(call package_recurse,$(abspath $(CURDIR)/../$(strip $(DEP))),$(strip $(DEP)))))
else
.DEFAULT_GOAL:=$(CURDIR)_OUTPUT_EZS_PATHS

ifeq "$(MAKECMDGOALS)" ""
TESTABLEGOALS:=$(.DEFAULT_GOAL)
else
TESTABLEGOALS:=$(MAKECMDGOALS)
endif

BASE_CASE_DONE:=true
$(eval $(call package_recurse,$(CURDIR),$(notdir $(CURDIR))))
endif
