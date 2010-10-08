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

export GLOBAL_VERSION ?= 0.0.0
export ERLC ?= erlc
export ERL ?= erl
export TMPDIR ?= /tmp

export GLOBAL_ERLC_OPTS ?= -Wall +debug_info

export DIST_DIR ?= dist
export DEPS_DIR ?= deps

export ERL_CALL ?= erl_call
export NODENAME:=rabbit-test
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

endif
