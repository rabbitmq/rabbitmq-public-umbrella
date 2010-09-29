# The purpose of this file is to drive the main recursive inclusion of
# Makefiles based on the current package's dependencies. It sets up
# the PACKAGE_DIR and PACKAGE_NAME variables before recursive
# inclusion, as well as setting up reverse pointers from the child
# back to the parent. These are important and used by common.mk.
#
# It also checks to see if the dependency points to a non-integrated
# target and if so then treats the dependency specially.
#
# The last thing that occurs prior to recursion into a child is the
# inclusion of targets.mk. The same package may be visited several
# times owing to the diamond problem. Because parent pointers thus
# expand (see common.mk), descent through children may happen more
# than once.

define package_deps
# child abspath is in $(1). $(PACKAGE_DIR) is the parent package at
# this point.

# Set up a pointer from the child back to its parents
$(1)_PARENTS:=$(PACKAGE_DIR) $($(1)_PARENTS)
#$$(info $(1) parents are $$($(1)_PARENTS))

# Append the current child to the list of deps for the parent
$(PACKAGE_DIR)_DEPS:=$(1) $($(PACKAGE_DIR)_DEPS)
#$$(info $(PACKAGE_DIR)_DEPS = $$($(PACKAGE_DIR)_DEPS))
endef

define package_recurse
# child abspath is in $(1). Child name is in $(2)
PACKAGE_DIR:=$(1)
PACKAGE_NAME:=$(2)
ifeq "$(filter $(notdir $(strip $(1))),$(NON_INTEGRATED))" ""
$(foreach VAR,$(VARS),$(eval $(VAR):=undefined))
DEPS:=
include $(strip $(1))/Makefile
else
include ../non-integrated.mk
endif
endef

ifdef BASE_CASE_DONE
include ../targets.mk
$(foreach DEP,$(DEPS),$(eval $(call package_deps,$(abspath $(CURDIR)/../$(strip $(DEP))))))
$(foreach DEP,$(DEPS),$(eval $(call package_recurse,$(abspath $(CURDIR)/../$(strip $(DEP))),$(strip $(DEP)))))
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
