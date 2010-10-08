# Introduction
# ============
#
# If you're a plugin developer and want to get your plugin to work
# with the build system, please see the README_Makefiles file.
#
# Internal notes
# ==============
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

include ../global.mk

# be careful if reordering these.
VARS:=SOURCE_DIR SOURCE_ERLS INCLUDE_DIR INCLUDE_HRLS EBIN_DIR EBIN_BEAMS DEPS_FILE APP_NAME OUTPUT_EZS INTERNAL_DEPS EXTRA_PACKAGE_DIRS EXTRA_TARGETS GENERATED_ERLS VERSION OUTPUT_EZS_PATHS INTERNAL_DEPS_PATHS ERLC_OPTS TEST_DIR TEST_SOURCE_DIR TEST_SOURCE_ERLS TEST_EBIN_DIR TEST_EBIN_BEAMS TEST_COMMANDS TEST_SCRIPTS RELEASABLE

ifdef PACKAGE_DIR

define package_to_app_name
$(subst __,_,$(patsubst rabbitmq%,rabbit_%,$(subst -,_,$(1))))
endef

DEFAULT_SOURCE_DIR:=$$(PACKAGE_DIR)/src
DEFAULT_SOURCE_ERLS:=$$(wildcard $$($$(PACKAGE_DIR)_SOURCE_DIR)/*.erl)

DEFAULT_INCLUDE_DIR:=$$(PACKAGE_DIR)/include
DEFAULT_INCLUDE_HRLS:=$$(wildcard $$($$(PACKAGE_DIR)_INCLUDE_DIR)/*.hrl)

DEFAULT_EBIN_DIR:=$$(PACKAGE_DIR)/ebin
DEFAULT_EBIN_BEAMS:=$$(patsubst $$($$(PACKAGE_DIR)_SOURCE_DIR)/%.erl,$$($$(PACKAGE_DIR)_EBIN_DIR)/%.beam,$$($$(PACKAGE_DIR)_SOURCE_ERLS))

DEFAULT_APP_NAME:=$$(call package_to_app_name,$$(PACKAGE_NAME))
DEFAULT_OUTPUT_EZS:=$$($$(PACKAGE_DIR)_APP_NAME)
DEFAULT_DEPS_FILE:=$$(PACKAGE_DIR)/deps.mk
DEFAULT_VERSION:=$$(GLOBAL_VERSION)
DEFAULT_OUTPUT_EZS_PATHS:=$$(patsubst %,$$(PACKAGE_DIR)/$(DIST_DIR)/%-$$($$(PACKAGE_DIR)_VERSION).ez,$$($$(PACKAGE_DIR)_OUTPUT_EZS))
DEFAULT_INTERNAL_DEPS_PATHS:=$$(patsubst %,$$(PACKAGE_DIR)/$(DIST_DIR)/%-$$($$(PACKAGE_DIR)_VERSION).ez,$$($$(PACKAGE_DIR)_INTERNAL_DEPS))

DEFAULT_TEST_DIR:=$$(PACKAGE_DIR)/test
DEFAULT_TEST_SOURCE_DIR:=$$($$(PACKAGE_DIR)_TEST_DIR)/src
DEFAULT_TEST_SOURCE_ERLS:=$$(wildcard $$($$(PACKAGE_DIR)_TEST_SOURCE_DIR)/*.erl)
DEFAULT_TEST_EBIN_DIR:=$$($$(PACKAGE_DIR)_TEST_DIR)/ebin
DEFAULT_TEST_EBIN_BEAMS:=$$(patsubst $$($$(PACKAGE_DIR)_TEST_SOURCE_DIR)/%.erl,$$($$(PACKAGE_DIR)_TEST_EBIN_DIR)/%.beam,$$($$(PACKAGE_DIR)_TEST_SOURCE_ERLS))

# This function is used to lift variables into the $(PACKAGE_DIR)
# namespace. If the variable contains the text "undefined", then the
# default value is used. The use of eval, and the $-escaping within
# the DEFAULT_* variables introduces laziness: the values can refer to
# other variables which are not defined. E.g. in the package Makefile,
# you can refer to $$(SOURCE_DIR) without declaring SOURCE_DIR and
# thus rely on the default value.
# variable name is in $(1), default variable expression is in $(2)
define lift_var
ifeq "$($(1))" "undefined"
$$(eval $(PACKAGE_DIR)_$(1):=$(2))
else
$$(eval $(PACKAGE_DIR)_$(1):=$($(1)))
endif
endef

$(foreach VAR,$(VARS),$(eval $(call lift_var,$(VAR),$(DEFAULT_$(VAR)))))

$(PACKAGE_DIR)_SOURCE_ERLS += $($(PACKAGE_DIR)_GENERATED_ERLS)

# $(info I am $(PACKAGE_DIR) and my parents are $($(PACKAGE_DIR)_PARENTS))

define dump_var
$(1):=$($(1))
$(PACKAGE_DIR)_$(1):=$($(PACKAGE_DIR)_$(1))
endef

ifdef DUMP_VARS
$(foreach VAR,$(VARS),$(info $(call dump_var,$(VAR))))
endif

ifeq "$(TOP_LEVEL)" "true"
TOP_LEVEL:=false
include ../top.mk
endif

include ../common.mk

else
TOP_LEVEL:=true
endif # ifdef PACKAGE_DIR

include ../deps.mk
