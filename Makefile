.PHONY: default
default:
	@echo No default target

# PLUGIN_REPOS = our plugins repos; what needs to be tagged at release time.
# CORE_REPOS = PLUGIN_REPOS + server and codegen, i.e. everything we can hg
# clone from http://hg.rabbitmq.com/.
# REPOS = CORE_REPOS + external repos, i.e. everything we need to clone /
# checkout in any way.
# PLUGINS = PLUGIN_REPOS + external repos, i.e. every plugin we need to build.

PLUGIN_REPOS=rabbitmq-erlang-client \
           rabbitmq-jsonrpc rabbitmq-mochiweb \
           rabbitmq-jsonrpc-channel rabbitmq-management-agent \
           rabbitmq-management rabbitmq-stomp rabbitmq-smtp rabbitmq-shovel

CORE_REPOS=rabbitmq-server rabbitmq-codegen $(PLUGIN_REPOS)

REPOS=$(CORE_REPOS) erlang-rfc4627
BRANCH=default
PLUGINS=rabbitmq-erlang-client rabbitmq-jsonrpc rabbitmq-mochiweb \
	rabbitmq-jsonrpc-channel erlang-rfc4627 rabbitmq-smtp \
	rabbitmq-stomp rabbitmq-shovel rabbitmq-management-agent \
	rabbitmq-management

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

.PHONY: co
co: checkout

.PHONY: ci
ci: checkin

.PHONY: up
up: update

.PHONY: st
st: status

.PHONY: up_c
up_c: named_update

#----------------------------------

.PHONY: checkout
checkout: $(foreach REP,$(REPOS),$(CURDIR)/$(REP)/Makefile)

#----------------------------------

.PHONY: release
release: checkout
	$(foreach DIR,$(PLUGIN_REPOS),$(MAKE) -C $(DIR) release GLOBAL_VERSION=$(VERSION) &&) true

#----------------------------------

.PHONY: clean
clean:
	$(foreach DIR,$(REPOS),$(MAKE) -C $(DIR) clean;)

#----------------------------------
# Subrepository management

.PHONY: status
status: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg st -mad) &&) true

.PHONY: pull
pull: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg pull) &&) true

.PHONY: update
update: pull
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg up) &&) true

.PHONY: named_update
named_update: pull
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg up -C $(BRANCH));)

.PHONY: tag
tag: checkout
	$(foreach DIR,. $(PLUGIN_REPOS),(cd $(DIR); hg tag $(TAG));)

.PHONY: push
push: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg push -f);)

.PHONY: checkin
checkin: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg ci);)

#----------------------------------
# Plugin management

plugins-dist: release
	rm -rf $(PLUGINS_DIST_DIR)
	mkdir -p $(PLUGINS_DIST_DIR)
	find . -name '*.ez' -exec cp -f {} $(PLUGINS_DIST_DIR) \;
