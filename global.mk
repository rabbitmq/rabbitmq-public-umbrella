ifndef INCLUDE_GLOBAL
INCLUDE_GLOBAL:=true

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

.PHONY: clean
clean::

%/$(DEPS_DIR):
	mkdir $@

%/$(DIST_DIR):
	mkdir $@

UMBRELLA_BASE_DIR:=$(abspath $(CURDIR)/..)
include ../repos.mk

endif
