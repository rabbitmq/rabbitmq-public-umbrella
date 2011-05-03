.PHONY: default
default:
	@echo No default target && false

PACKAGE_REPOS:=\
    eldap-wrapper \
    erlando \
    erlang-rfc4627-wrapper \
    hstcp \
    mochiweb-wrapper \
    rabbitmq-auth-backend-ldap \
    rabbitmq-auth-mechanism-ssl \
    rabbitmq-external-exchange \
    rabbitmq-jsonrpc \
    rabbitmq-jsonrpc-channel \
    rabbitmq-jsonrpc-channel-examples \
    rabbitmq-management \
    rabbitmq-management-agent \
    rabbitmq-metronome \
    rabbitmq-mochiweb \
    rabbitmq-shovel \
    rabbitmq-stomp \
    rabbitmq-toke \
    toke \
    webmachine-wrapper

REPOS:=rabbitmq-server rabbitmq-erlang-client rabbitmq-codegen $(PACKAGE_REPOS)

BRANCH:=default

HG_CORE_REPOBASE:=$(shell dirname `hg paths default 2>/dev/null` 2>/dev/null)
ifndef HG_CORE_REPOBASE
HG_CORE_REPOBASE:=http://hg.rabbitmq.com/
endif

VERSION:=0.0.0

#----------------------------------

all:
	$(MAKE) -f all-packages.mk all-packages VERSION=$(VERSION)

test:
	$(MAKE) -f all-packages.mk test-all-packages VERSION=$(VERSION)

release:
	$(MAKE) -f all-packages.mk all-releasable VERSION=$(VERSION)

clean:
	$(MAKE) -f all-packages.mk clean-all-packages

plugins-dist: release
	rm -rf $(PLUGINS_DIST_DIR)
	mkdir -p $(PLUGINS_DIST_DIR)
	$(MAKE) -f all-packages.mk copy-releasable VERSION=$(VERSION) $(PLUGINS_DIST_DIR)=$(PLUGINS_DIST_DIR)

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

$(REPOS):
	hg clone $(HG_CORE_REPOBASE)/$@

.PHONY: checkout
checkout: $(REPOS)

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
	$(foreach DIR,. $(PACKAGE_REPOS),(cd $(DIR); hg tag $(TAG));)

.PHONY: push
push: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg push -f);)

.PHONY: checkin
checkin: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg ci);)
