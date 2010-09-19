include ../global.mk

#
#      ebin/$(APP_NAME).app -?-> ebin/$(APP_NAME)_app.in
#       ^
#       |
# --> $(DIST_DIR)/$(OUTPUT_EZS) -|-> $(DIST_DIR)
#       |
#       +------------------------------------\
#       |                                     V
#       |            /--> deps.mk --\   /--> include/*.hrl
#       V            |               }-{
#      ebin/*.beam --+--------------/   \--> src/*.erl
#                    |
#                    \--> $(DIST_DIR)/$(OUTPUT_EZS).stamp
#                           |
#                           V
#                          $(DEPS)/$(DIST_DIR)/$(OUTPUT_EZS) [RECURSE] -->
#
# Notes
#
# 1. The contents of deps.mk itself expresses the dependencies between
# the beams and erls/hrls.
#
# 2. If package foo depends on bar, and package bar depends on baz,
# then when compiling foo, the .ezs from _both_ bar and baz must be
# present in foo. I.e. the transitive closure of OUTPUT_EZS is
# required as we move up the dependency chain. This is not represented
# in the above diagram.
#
# 3. The contents of global.mk are included just once.
#
# 4. common.mk is included every time we visit a package. This is true
# even if we've already visited a package and is essential as we may
# discover a package has more parents than we'd previously thought and
# the dependencies for OUTPUT_EZS needs correcting (see point 2
# above). E.g. foo -> bar; foo -> baz; bar -> qux; baz -> qux: when
# visiting qux, we need to ensure both bar and baz depend on the
# qux.ez outputs.
#
# 5. targets.mk is only included for fully integrated packages and is
# only included once per package.
#
# 6. non-integrated.mk is included only for non-integrated packages
# (currently erlang-client and server) and is only included once per
# such package.
#
# 7. For general debugging and understanding, try changing $(eval ...)
# calls to $(info ...) calls and then it'll break, but print out what
# Makefile fragments have been generated and were to be interpreted.
#
# 8. Support for non integrated packages errs on the safe-side: the
# output EZs of such packages are declared PHONY. As a result,
# whenever such a package is a prerequisite, all subsequent steps will
# always be taken. However, make -j still works, and there is no
# possibility of missing changes.
#

VARS:=SOURCE_DIR SOURCE_ERLS INCLUDE_DIR INCLUDE_HRLS EBIN_DIR EBIN_BEAMS DEPS_FILE APP_NAME OUTPUT_EZS INTERNAL_DEPS

ifdef PACKAGE_DIR

define default_and_lift_var
ifeq ($(origin $(1)), undefined)
$(PACKAGE_DIR)_$(1):=$(2)
else
ifeq ($($(1)), undefined)
$(PACKAGE_DIR)_$(1):=$(2)
else
$(PACKAGE_DIR)_$(1):=$($(1))
endif
endif
endef

define lift_undef
ifeq ($(origin $(PACKAGE_DIR)_$(1)), undefined)
$(PACKAGE_DIR)_$(1):=$($(1))
endif
endef

define package_to_app_name
  $(subst __,_,$(patsubst rabbitmq%,rabbit_%,$(subst -,_,$(1))))
endef

$(eval $(call default_and_lift_var,SOURCE_DIR,$(PACKAGE_DIR)/src))
$(eval $(call default_and_lift_var,SOURCE_ERLS,$(wildcard $($(PACKAGE_DIR)_SOURCE_DIR)/*.erl)))

$(eval $(call default_and_lift_var,INCLUDE_DIR,$(PACKAGE_DIR)/include))
$(eval $(call default_and_lift_var,INCLUDE_HRLS,$(wildcard $($(PACKAGE_DIR)_INCLUDE_DIR)/*.hrl)))

$(eval $(call default_and_lift_var,EBIN_DIR,$(PACKAGE_DIR)/ebin))
$(eval $(call default_and_lift_var,EBIN_BEAMS,$(patsubst $($(PACKAGE_DIR)_SOURCE_DIR)/%.erl,$($(PACKAGE_DIR)_EBIN_DIR)/%.beam,$($(PACKAGE_DIR)_SOURCE_ERLS))))

$(eval $(call default_and_lift_var,APP_NAME,$(call package_to_app_name,$(PACKAGE_NAME))))
$(eval $(call default_and_lift_var,OUTPUT_EZS,$(PACKAGE_NAME).ez))
$(eval $(call default_and_lift_var,DEPS_FILE,$(PACKAGE_DIR)/deps.mk))

$(foreach VAR,$(VARS),$(eval $(call lift_undef,$(VAR))))

# $(info I am $(PACKAGE_DIR) and my parents are $($(PACKAGE_DIR)_PARENTS))

define dump_var
$(1):=$($(1))
$(PACKAGE_DIR)_$(1):=$($(PACKAGE_DIR)_$(1))
endef

# $(foreach VAR,$(VARS),$(info $(call dump_var,$(VAR))))

ifeq "$(SET_DEFAULT_GOAL)" "true"
SET_DEFAULT_GOAL:=false
.DEFAULT_GOAL:=$(PACKAGE_DIR)_OUTPUT_EZS

.PHONY: $(PACKAGE_DIR)_OUTPUT_EZS
$(foreach EZ,$($(PACKAGE_DIR)_OUTPUT_EZS),$(eval $(PACKAGE_DIR)_OUTPUT_EZS: $(PACKAGE_DIR)/$(DIST_DIR)/$(EZ)))
endif

include ../common.mk

else
SET_DEFAULT_GOAL:=true
endif

include ../deps.mk
