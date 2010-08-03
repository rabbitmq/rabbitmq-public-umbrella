# The order of these repos is VERY important because some repos depend on
# other repos, so be careful when palying with this

CORE_REPOS=rabbitmq-server rabbitmq-codegen rabbitmq-erlang-client \
           rabbitmq-jsonrpc rabbitmq-mochiweb \
           rabbitmq-jsonrpc-channel rabbitmq-bql \
           rabbitmq-stomp rabbitmq-smtp rabbitmq-status rabbitmq-shovel

REPOS=$(CORE_REPOS) erlang-rfc4627
BRANCH=default
PLUGINS=rabbitmq-erlang-client rabbitmq-jsonrpc rabbitmq-mochiweb \
	rabbitmq-jsonrpc-channel rabbitmq-bql erlang-rfc4627 rabbitmq-smtp \
	rabbitmq-stomp rabbitmq-status rabbitmq-shovel

HG_CORE_REPOBASE:=$(shell dirname `hg paths default 2>/dev/null` 2>/dev/null)

ifeq ($(HG_CORE_REPOBASE),)
HG_CORE_REPOBASE=http://hg.rabbitmq.com/
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

erlang-rfc4627:
	git clone http://github.com/tonyg/erlang-rfc4627.git

checkout: $(REPOS)

st: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg st -mad) &&) true

pull: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg pull) &&) true

update: pull
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg up) &&) true

named_update: checkout
	$(foreach DIR,. $(CORE_REPOS),(cd $(DIR); hg up -C $(BRANCH));)

tag: checkout
	$(foreach DIR,. $(CORE_REPOS),(cd $(DIR); hg tag $(TAG));)

push: checkout
	$(foreach DIR,. $(CORE_REPOS),(cd $(DIR); hg push -f);)

#----------------------------------
# Plugin management
attach_plugins:
	mkdir -p rabbitmq-server/plugins
	rm -f rabbitmq-server/plugins/*
	$(foreach DIR, $(PLUGINS), (cd rabbitmq-server/plugins; ln -sf ../../$(DIR)) &&) true
	$(foreach DIR, $(PLUGINS), $(foreach DEP, $(shell make -s -C $(DIR) list-deps), (cd rabbitmq-server/plugins; ln -sf ../../$(DIR)/$(DEP)) &&)) true
	rabbitmq-server/scripts/rabbitmq-activate-plugins

plugins-dist: package
	rm -rf $(PLUGINS_DIST_DIR)
	mkdir -p $(PLUGINS_DIST_DIR)
	find . -name '*.ez' -exec cp -f {} $(PLUGINS_DIST_DIR) \;
	for file in $(PLUGINS_DIST_DIR)/*.ez ; \
	  do mv $${file} \
	    $$(dirname $${file})/$$(basename $${file} .ez)-$(VERSION).ez ; \
	  done
