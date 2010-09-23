ifndef INCLUDE_GLOBAL
INCLUDE_GLOBAL:=true

export GLOBAL_VERSION ?= 0.0.0
export ERLC ?= erlc
export ERL ?= erl
export TMPDIR ?= /tmp

export ERLC_OPTS ?= -Wall +debug_info

export DIST_DIR ?= dist
export DEPS_DIR ?= deps

NON_INTEGRATED:=rabbitmq-server rabbitmq-erlang-client erlang-rfc4627

$(abspath $(CURDIR)/../rabbitmq-erlang-client)_OUTPUT_EZS:=amqp_client rabbit_common
$(abspath $(CURDIR)/../rabbitmq-erlang-client)_VERSION:=$(GLOBAL_VERSION)

$(abspath $(CURDIR)/../rabbitmq-server)_OUTPUT_EZS:=
$(abspath $(CURDIR)/../rabbitmq-server)_VERSION:=$(GLOBAL_VERSION)

$(abspath $(CURDIR)/../erlang-rfc4627)_OUTPUT_EZS:=rfc4627_jsonrpc
$(abspath $(CURDIR)/../erlang-rfc4627)_VERSION:=$(GLOBAL_VERSION)

ifeq "$(MAKECMDGOALS)" ""
TESTABLEGOALS:=$(.DEFAULT_GOAL)
else
TESTABLEGOALS:=$(MAKECMDGOALS)
endif

.PHONY: clean
clean::

%/$(DEPS_DIR):
	mkdir $@

%/$(DIST_DIR):
	mkdir $@

endif
