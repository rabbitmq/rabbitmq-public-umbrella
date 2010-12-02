# The purpose of this file is to drive the main recursive inclusion of
# Makefiles based on the current package's dependencies. It sets up
# the PACKAGE_DIR and PACKAGE_NAME variables before recursive
# inclusion.
#
# It also checks to see if the dependency points to a non-integrated
# target and if so then treats the dependency specially.
#
# The last thing that occurs prior to recursion into a child is the
# inclusion of targets.mk (or, if the child is non-integrated, the
# inclusion of non-integrated as the recursive step (i.e. no real
# recursion in this case)).

define package_recurse
# child abspath is in $(1). Child name is in $(2)
PACKAGE_DIR:=$(1)
PACKAGE_NAME:=$(2)
$(2)_DIR:=$(1)
ifndef $(1)_VISITED
$(1)_VISITED:=true
PACKAGE_NAMES += $(2)
ifeq "$(filter $(notdir $(1)),$(NON_INTEGRATED))" ""
include ../package.mk
else
include ../non-integrated.mk
endif
endif
endef

ifdef BASE_CASE_DONE
include ../targets.mk
$(foreach DEP,$($(PACKAGE_DIR)_DEPS),$(eval $(call package_recurse,$(strip $(abspath $(CURDIR)/../$(strip $(DEP)))),$(strip $(DEP)))))
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
