# This file is included both by the public-umbrella Makefile, and by
# the global.mk file, thus used by all plugins. It is the only place
# which should contain an listing of available plugins, and knows how
# to check out any such plugin.
#
# UMBRELLA_BASE_DIR must be set before including this file.
#
# PLUGIN_REPOS should include every package that has a "release"
# target: i.e. integrated packages only. Thus it should include
# plugins, and their dependencies, but not things that are built,
# tagged and release separately: i.e. the core components.

PLUGIN_REPOS:=erlang-rfc4627-wrapper \
              erlang-smtp-wrapper \
              mochiweb-wrapper \
              rabbitmq-bql \
              rabbitmq-external-exchange \
              rabbitmq-jsonrpc \
              rabbitmq-jsonrpc-channel \
              rabbitmq-management \
              rabbitmq-mochiweb \
              rabbitmq-shovel \
              rabbitmq-smtp \
              rabbitmq-status \
              rabbitmq-stomp \
              rabbitmq-toke \
              toke \
              webmachine-wrapper

CORE_REPOS:=rabbitmq-codegen rabbitmq-server rabbitmq-erlang-client

REPOS:=$(PLUGIN_REPOS) $(CORE_REPOS)

HG_CORE_REPOBASE:=$(shell dirname `hg paths default 2>/dev/null` 2>/dev/null)

ifeq ($(HG_CORE_REPOBASE),)
HG_CORE_REPOBASE:=http://hg.rabbitmq.com/
endif

# TODO ON MERGE TO DEFAULT: set branch back to default
BRANCH:=bug23274

$(patsubst %,$(UMBRELLA_BASE_DIR)/%/Makefile,$(REPOS)):
	cd $(UMBRELLA_BASE_DIR) && hg clone $(HG_CORE_REPOBASE)/$(notdir $(@D))
	-cd $(@D) && hg up -C $(BRANCH)
