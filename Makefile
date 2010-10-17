.PHONY: default
default:
	@echo No default target

UMBRELLA_BASE_DIR:=$(CURDIR)
include repos.mk

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
