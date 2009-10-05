# The order of these repos is VERY important because some repos depend on
# other repos, so be careful when palying with this

CORE_REPOS=rabbitmq-server rabbitmq-codegen rabbitmq-erlang-client \
           rabbitmq-jsonrpc rabbitmq-mochiweb \
           rabbitmq-jsonrpc-channel rabbitmq-bql \
           rabbitmq-stomp rabbitmq-smtp

OS_REPOS=erlang-rfc4627
REPOS=$(CORE_REPOS) $(OS_REPOS)
BRANCH=default
PLUGINS=rabbitmq-erlang-client rabbitmq-jsonrpc rabbitmq-mochiweb rabbitmq-jsonrpc-channel \
        rabbitmq-bql erlang-rfc4627 rabbitmq-smtp rabbitmq-stomp

HG_CORE_REPOBASE:=$(shell dirname `hg paths default 2>/dev/null` 2>/dev/null)

ifeq ($(HG_CORE_REPOBASE),)
HG_CORE_REPOBASE=http://hg.rabbitmq.com/
endif

ifeq ($(shell echo $(HG_CORE_REPOBASE) | cut -c1-3),ssh)
HG_OS_REPOBASE=ssh://hg@hg.opensource.lshift.net
else
HG_OS_REPOBASE=http://hg.opensource.lshift.net
endif

#----------------------------------

all:
	$(foreach DIR, $(REPOS), $(MAKE) -C $(DIR) all &&) true

package:
	$(foreach DIR, $(PLUGINS), $(MAKE) -C $(DIR) package &&) true

#----------------------------------
# Convenience aliases

co: checkout
up: update

#----------------------------------

clean:
	$(foreach DIR, $(REPOS), $(MAKE) -C $(DIR) clean;)

#----------------------------------
# Subrepository management

$(CORE_REPOS):
	hg clone $(HG_CORE_REPOBASE)/$@

$(OS_REPOS):
	hg clone $(HG_OS_REPOBASE)/$@

checkout: $(REPOS)

st: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg st -mad) &&) true

pull: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg pull) &&) true

update: pull
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg up) &&) true

named_update: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg up -C $(BRANCH));)

#----------------------------------
# Plugin management
attach_plugins:
	mkdir -p rabbitmq-server/plugins
	rm -f rabbitmq-server/plugins/*
	$(foreach DIR, $(PLUGINS), (cd rabbitmq-server/plugins; ln -sf ../../$(DIR)) &&) true
	$(foreach DIR, $(PLUGINS), $(foreach DEP, $(shell make -s -C $(DIR) list-deps), (cd rabbitmq-server/plugins; ln -sf ../../$(DIR)/$(DEP)) &&)) true
	rabbitmq-server/scripts/rabbitmq-activate-plugins

bundle: package
	rm -rf $(DIST_DIR)
	mkdir -p $(DIST_DIR)/plugins
	find . -name '*.ez' -exec cp {} $(DIST_DIR)/plugins \;
	(cd $(DIST_DIR); zip -r plugins.zip plugins/)
