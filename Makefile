include include.mk

# The order of these repos is VERY important because some repos depend on
# other repos, so be careful when palying with this

CORE_REPOS=rabbitmq-server rabbitmq-codegen rabbitmq-erlang-client \
           rabbitmq-http2
PLUGIN_REPOS=erlang-rfc4627 mod_http mod_bql
REPOS=$(CORE_REPOS) $(PLUGIN_REPOS)
BRANCH=default
PLUGINS=$(PLUGIN_REPOS) rabbitmq-erlang-client rabbitmq-http2

HGREPOBASE:=$(shell dirname `hg paths default 2>/dev/null` 2>/dev/null)
HG_CORE_REPOSBASE=ssh://hg@hg.lshift.net

ifeq ($(HGREPOBASE),)
HGREPOBASE=ssh://hg@hg.opensource.lshift.net
endif

#----------------------------------

all:
	$(foreach DIR, $(REPOS), $(MAKE) -C $(DIR) all;)

package:
	$(foreach DIR, $(REPOS), $(MAKE) -C $(DIR) package;)

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
	hg clone $(HG_CORE_REPOSBASE)/$@

$(PLUGIN_REPOS):
	hg clone $(HGREPOBASE)/$@

checkout: $(REPOS)

st: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg st -mad);)

pull: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg pull);)

update: pull
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg up);)

named_update: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg up -C $(BRANCH));)

#----------------------------------
# Plugin management
attach_plugins:
	mkdir -p rabbitmq-server/plugins
	$(foreach DIR, $(PLUGINS), (cd rabbitmq-server/plugins; ln -sf ../../$(DIR));)
	(cd rabbitmq-server/plugins; ln -sf ../../mod_http/mochiweb)
	rabbitmq-server/scripts/activate-plugins

bundle: package
	rm -rf $(DIST_DIR)
	mkdir -p $(DIST_DIR)/plugins
	find . -name '*.ez' -exec cp {} $(DIST_DIR)/plugins \;
	(cd $(DIST_DIR); zip -r plugins.zip plugins/)




