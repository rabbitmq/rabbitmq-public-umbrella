# This file is included once, immediately after parsing the package
# Makefile for the first time. Thus no package-specific variables are
# set at all at this point, nor should any package alter the variables
# set here. It is expected that any variables set here may be
# overridden by the command line invocation only.
#
# This file exists to set up constants, common targets, and to set the
# relevant variables for non-integrated targets. In that spirit, it
# also includes repos.mk, to bring in knowledge of how to checkout any
# of the known repositories.

ifndef INCLUDE_GLOBAL
INCLUDE_GLOBAL:=true

# This is the standard trick for making pattern substitution work
# (amongst others) when the replacement needs to include a comma.
COMMA:=,

PACKAGE_NAMES:=

VARS:=SOURCE_DIR \
      SOURCE_ERLS \
      INCLUDE_DIR \
      INCLUDE_HRLS \
      EBIN_DIR \
      EBIN_BEAMS \
      DEPS_FILE \
      APP_NAME \
      OUTPUT_EZS \
      INTERNAL_DEPS \
      EXTRA_PACKAGE_DIRS \
      EXTRA_TARGETS \
      GENERATED_ERLS \
      VERSION \
      OUTPUT_EZS_PATHS \
      INTERNAL_DEPS_PATHS \
      ERLC_OPTS \
      TEST_DIR \
      TEST_SOURCE_DIR \
      TEST_SOURCE_ERLS \
      TEST_EBIN_DIR \
      TEST_EBIN_BEAMS \
      TEST_COMMANDS \
      TEST_SCRIPTS \
      RELEASABLE \
      DEPS

export GLOBAL_VERSION ?= 0.0.0
export ERLC ?= erlc
export ERL ?= erl
export TMPDIR ?= /tmp

export GLOBAL_ERLC_OPTS ?= -Wall +debug_info

export DIST_DIR ?= dist
export DEPS_DIR ?= deps

export ERL_CALL ?= erl_call
export NODENAME:=rabbit-test@$(shell hostname -s)
export ERL_CALL_OPTS:=-sname $(NODENAME) -e

NON_INTEGRATED:=rabbitmq-server rabbitmq-erlang-client

$(abspath $(CURDIR)/../rabbitmq-erlang-client)_OUTPUT_EZS:=amqp_client rabbit_common
$(abspath $(CURDIR)/../rabbitmq-erlang-client)_VERSION:=$(GLOBAL_VERSION)

$(abspath $(CURDIR)/../rabbitmq-server)_OUTPUT_EZS:=
$(abspath $(CURDIR)/../rabbitmq-server)_VERSION:=$(GLOBAL_VERSION)

%/$(DEPS_DIR):
	mkdir $@

%/$(DIST_DIR):
	mkdir $@

UMBRELLA_BASE_DIR:=$(abspath $(CURDIR)/..)
include ../repos.mk

define package_to_app_name
$(subst __,_,$(patsubst rabbitmq%,rabbit_%,$(subst -,_,$(1))))
endef

# This function is used to lift variables into the $(PACKAGE_DIR)
# namespace. The use of simple assignment is deliberate at this point
# to force evaluation and capture of any recursively-declared
# variables.
# variable name is in $(1), namespace is in $(2)
define lift_var
$$(eval $(2)_$(1):=$($(1)))
endef

define dump_var
$(1):=$($(1))
$(PACKAGE_DIR)_$(1):=$($(PACKAGE_DIR)_$(1))
endef

endif
