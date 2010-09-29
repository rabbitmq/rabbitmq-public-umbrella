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
	cd $(UMBRELLA_BASE_DIR) && hg clone $(HG_CORE_REPOBASE)/$(notdir $(@D)) -r $(BRANCH)
