# This file is included both by the public-umbrella Makefile, and by
# the global.mk file, thus used by all plugins. It is the only place
# which should contain an listing of available plugins, and knows how
# to check out any such plugin.
#
# If this file is not within the CURDIR, UMBRELLA_BASE_DIR should be
# set to the abspath to the rabbitmq-public-umbrella directory.

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

ifndef UMBRELLA_BASE_DIR
UMBRELLA_BASE_DIR:=$(CURDIR)
endif

HG_CORE_REPOBASE:=$(shell dirname `hg paths default 2>/dev/null` 2>/dev/null)

ifeq ($(HG_CORE_REPOBASE),)
HG_CORE_REPOBASE:=http://hg.rabbitmq.com/
endif

# TODO ON MERGE TO DEFAULT: set branch back to default
BRANCH:=bug23274

$(patsubst %,$(UMBRELLA_BASE_DIR)/%/Makefile,$(REPOS)):
	cd $(UMBRELLA_BASE_DIR) && hg clone $(HG_CORE_REPOBASE)/$(notdir $(@D))
	-cd $(@D) && hg up -C $(BRANCH)
