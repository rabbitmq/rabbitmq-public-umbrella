ifndef INCLUDE_GLOBAL
INCLUDE_GLOBAL:=true

VERSION ?= 0.0.0
ERLC ?= erlc
ERL ?= erl
TMPDIR ?= /tmp

ERLC_OPTS ?= -Wall +debug_info

DIST_DIR ?= dist
DEPS_DIR ?= deps

NON_INTEGRATED:=rabbitmq-server rabbitmq-erlang-client
$(abspath $(CURDIR)/../rabbitmq-erlang-client)_OUTPUT_EZS:=amqp_client.ez rabbit_common.ez
$(abspath $(CURDIR)/../rabbitmq-server)_OUTPUT_EZS:=

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
