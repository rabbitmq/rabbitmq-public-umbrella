# This is a TEMPORARY umbrella makefile, that will likely not survive
# the repo split.

VERSION=0.0.0
VDIR=v$(VERSION)
TAG=rabbitmq_$(subst .,_,$(VDIR))
BRANCH=default

SIGNING_KEY=056E8E56
SIGNING_USER_EMAIL=info@rabbitmq.com
SIGNING_USER_ID=RabbitMQ Release Signing Key <info@rabbitmq.com>

# Misc options to pass to hg commands
HG_OPTS=

# Misc options to pass to ssh commands
SSH_OPTS=

PACKAGES_DIR=packages
TMP_DIR=tmp

SERVER_PACKAGES_DIR=$(PACKAGES_DIR)/rabbitmq-server/$(VDIR)
MANPAGES_DIR=$(SERVER_PACKAGES_DIR)/man
JAVA_CLIENT_PACKAGES_DIR=$(PACKAGES_DIR)/rabbitmq-java-client/$(VDIR)
DOTNET_CLIENT_PACKAGES_DIR=$(PACKAGES_DIR)/rabbitmq-dotnet-client/$(VDIR)
ERLANG_CLIENT_PACKAGES_DIR=$(PACKAGES_DIR)/rabbitmq-erlang-client/$(VDIR)
PLUGINS_DIR=$(PACKAGES_DIR)/plugins/$(VDIR)
PLUGINS_SRC_DIR=$(TMP_DIR)/plugins-src/$(VDIR)
ABSOLUTE_PLUGINS_DIR=$(CURDIR)/$(PLUGINS_DIR)
ABSOLUTE_PLUGINS_SRC_DIR=$(CURDIR)/$(PLUGINS_SRC_DIR)

REQUIRED_EMULATOR_VERSION=5.6.5
ACTUAL_EMULATOR_VERSION=$(shell erl -noshell -eval 'io:format("~s",[erlang:system_info(version)]),init:stop().')
SKIP_EMULATOR_VERSION_CHECK=

REPOS:=rabbitmq-codegen rabbitmq-server rabbitmq-java-client rabbitmq-dotnet-client
REPOS_WITH_PUBLIC:=$(REPOS) rabbitmq-public-umbrella

HGREPOBASE:=$(shell dirname `hg paths default 2>/dev/null` 2>/dev/null)

ifeq ($(HGREPOBASE),)
HGREPOBASE=ssh://hg@hg.rabbitmq.com
endif


.PHONY: all
all:
	@echo Please choose a target from the Makefile.


.PHONY: checkout
checkout: $(foreach r,$(REPOS_WITH_PUBLIC),.$(r).checkout)

.%.checkout:
	[ -d $* ] || hg clone $(HG_OPTS) $(HGREPOBASE)/$*
	touch $@

.rabbitmq-public-umbrella.checkout:
	[ -d rabbitmq-public-umbrella ] || hg clone $(HG_OPTS) $(HGREPOBASE)/rabbitmq-public-umbrella
	$(MAKE) -C rabbitmq-public-umbrella checkout
	touch $@

.PHONY: named_update
named_update: checkout
	$(foreach r,. $(REPOS),hg pull -R $(r);hg update -R $(r) -C $(BRANCH);)
	$(MAKE) -C rabbitmq-public-umbrella named_update BRANCH=$(BRANCH)

.PHONY: tag
tag: checkout
	$(foreach r,. $(REPOS),hg tag -R $(r) $(TAG);)
	$(MAKE) -C rabbitmq-public-umbrella tag TAG=$(TAG)

.PHONY: push
push: checkout
	$(foreach r,. $(REPOS),hg push -R $(r) -f $(HG_OPTS);)
	$(MAKE) -C rabbitmq-public-umbrella push

.PHONY: dist
ifeq "$(UNOFFICIAL_RELEASE)$(GNUPG_PATH)" ""
dist:
	@echo "You must specify one of UNOFFICIAL_RELEASE (to true, if you don't want to sign packages) or GNUPG_PATH (to the location of the RabbitMQ keyring) when making dist."
	@false
else
dist: artifacts sign-artifacts
endif


.PHONY: clean
clean: rabbitmq-umbrella-clean $(foreach r,$(REPOS_WITH_PUBLIC),$(r)-clean)

.PHONY: rabbitmq-umbrella-clean
	rm -rf $(PACKAGES_DIR) $(TMP_DIR) .*.checkout

define clean-repo-template
.PHONY: $(1)-clean
$(1)-clean:
	[ ! -d $(1) ] || $(MAKE) -C $(1) clean

endef
$(eval $(foreach r,$(filter-out rabbitmq-server,$(REPOS_WITH_PUBLIC)),$(call clean-repo-template,$(r))))


.PHONY: prepare
prepare: checkout
ifeq "$(SKIP_EMULATOR_VERSION_CHECK)" ""
	@[ "$(REQUIRED_EMULATOR_VERSION)" = "$(ACTUAL_EMULATOR_VERSION)" ] || \
		(echo "You are trying to compile with the wrong Erlang/OTP release."; \
		echo "Please use emulator version $(REQUIRED_EMULATOR_VERSION)."; \
		echo "Or skip the version check by setting the variable SKIP_EMULATOR_VERSION_CHECK."; \
		[ -n "$(UNOFFICIAL_RELEASE)" ] )
endif
	@echo Checking the presence of the tools necessary to build a release on a Debian based OS.
	[ -f "/etc/debian_version" ] && dpkg -L cdbs elinks fakeroot findutils gnupg gzip perl python python-simplejson rpm rsync wget reprepro tar tofrodos zip python-pexpect openssl xmlto xsltproc git-core nsis > /dev/null || echo Not a Debian system
	@echo All required tools are installed, great!


.PHONY: artifacts
artifacts: rabbitmq-server-artifacts
artifacts: rabbitmq-java-artifacts
ifeq ($(SKIP_DOTNET_CLIENT),)
artifacts: rabbitmq-dotnet-artifacts
endif
artifacts: rabbitmq-erlang-client-artifacts
artifacts: rabbitmq-public-umbrella-srcdist
artifacts: rabbitmq-public-umbrella-artifacts


.PHONY: rabbitmq-server-clean
rabbitmq-server-clean:
	$(MAKE) -C rabbitmq-server distclean
	$(MAKE) -C rabbitmq-server/packaging/generic-unix clean
	$(MAKE) -C rabbitmq-server/packaging/windows clean
	$(MAKE) -C rabbitmq-server/packaging/windows-exe clean
	$(MAKE) -C rabbitmq-server/packaging/debs/Debian clean
	$(MAKE) -C rabbitmq-server/packaging/debs/apt-repository clean
	$(MAKE) -C rabbitmq-server/packaging/RPMS/Fedora clean
	$(MAKE) -C rabbitmq-server/packaging/macports clean

.PHONY: rabbitmq-server-artifacts
rabbitmq-server-artifacts: rabbitmq-server-srcdist
rabbitmq-server-artifacts: rabbitmq-server-website-manpages
rabbitmq-server-artifacts: rabbitmq-server-generic-unix-packaging
rabbitmq-server-artifacts: rabbitmq-server-windows-packaging
rabbitmq-server-artifacts: rabbitmq-server-windows-exe-packaging
rabbitmq-server-artifacts: rabbitmq-server-debian-packaging
rabbitmq-server-artifacts: rabbitmq-server-rpm-packaging

.PHONY: rabbitmq-server-srcdist
rabbitmq-server-srcdist: prepare rabbitmq-public-umbrella-srcdist
	$(MAKE) -C rabbitmq-server srcdist VERSION=$(VERSION) PLUGINS_SRC_DIR=$(ABSOLUTE_PLUGINS_SRC_DIR)
	mkdir -p $(SERVER_PACKAGES_DIR)
	cp rabbitmq-server/dist/rabbitmq-server-*.tar.gz rabbitmq-server/dist/rabbitmq-server-*.zip $(SERVER_PACKAGES_DIR)

.PHONY: rabbitmq-server-website-manpages
rabbitmq-server-website-manpages: rabbitmq-server-srcdist
	$(MAKE) -C rabbitmq-server docs_all VERSION=$(VERSION)
	mkdir -p $(MANPAGES_DIR)
	cp rabbitmq-server/docs/*.man.xml $(MANPAGES_DIR)

.PHONY: rabbitmq-server-generic-unix-packaging
rabbitmq-server-generic-unix-packaging: rabbitmq-server-srcdist
	$(MAKE) -C rabbitmq-server/packaging/generic-unix dist VERSION=$(VERSION)
	cp rabbitmq-server/packaging/generic-unix/rabbitmq-server-generic-unix-*.tar.gz $(SERVER_PACKAGES_DIR)

.PHONY: rabbitmq-server-mac-standalone-packaging
rabbitmq-server-mac-standalone-packaging: rabbitmq-server-srcdist
	$(MAKE) -C rabbitmq-server/packaging/standalone dist VERSION=$(VERSION)
	cp rabbitmq-server/packaging/standalone/rabbitmq-server-mac-standalone-*.tar.gz $(SERVER_PACKAGES_DIR)

.PHONY: rabbitmq-server-windows-packaging
rabbitmq-server-windows-packaging: rabbitmq-server-srcdist
	$(MAKE) -C rabbitmq-server/packaging/windows dist VERSION=$(VERSION)
	cp rabbitmq-server/packaging/windows/rabbitmq-server-windows-*.zip $(SERVER_PACKAGES_DIR)

.PHONY: rabbitmq-server-windows-exe-packaging
rabbitmq-server-windows-exe-packaging: rabbitmq-server-windows-packaging
	$(MAKE) -C rabbitmq-server/packaging/windows-exe dist VERSION=$(VERSION)
	cp rabbitmq-server/packaging/windows-exe/rabbitmq-server-*.exe $(SERVER_PACKAGES_DIR)

.PHONY: rabbitmq-server-debian-packaging
rabbitmq-server-debian-packaging: rabbitmq-server-srcdist
	$(MAKE) -C rabbitmq-server/packaging/debs/Debian package \
		UNOFFICIAL_RELEASE=$(UNOFFICIAL_RELEASE) \
		GNUPG_PATH=$(GNUPG_PATH) \
		VERSION=$(VERSION) \
		SIGNING_KEY_ID=$(SIGNING_KEY)
	cp rabbitmq-server/packaging/debs/Debian/rabbitmq-server*$(VERSION)*.deb $(SERVER_PACKAGES_DIR)
	cp rabbitmq-server/packaging/debs/Debian/rabbitmq-server*$(VERSION)*.diff.gz $(SERVER_PACKAGES_DIR)
	cp rabbitmq-server/packaging/debs/Debian/rabbitmq-server*$(VERSION)*.orig.tar.gz $(SERVER_PACKAGES_DIR)
	cp rabbitmq-server/packaging/debs/Debian/rabbitmq-server*$(VERSION)*.dsc $(SERVER_PACKAGES_DIR)
	cp rabbitmq-server/packaging/debs/Debian/rabbitmq-server*$(VERSION)*.changes $(SERVER_PACKAGES_DIR)
	$(MAKE) -C rabbitmq-server/packaging/debs/apt-repository all \
		UNOFFICIAL_RELEASE=$(UNOFFICIAL_RELEASE) \
		GNUPG_PATH=$(GNUPG_PATH) \
		SIGNING_USER_EMAIL=$(SIGNING_USER_EMAIL)
	cp -r rabbitmq-server/packaging/debs/apt-repository/debian $(PACKAGES_DIR)

.PHONY: rabbitmq-server-rpm-packaging
rabbitmq-server-rpm-packaging: rabbitmq-server-srcdist
	for distro in fedora suse ; do \
	  $(MAKE) -C rabbitmq-server/packaging/RPMS/Fedora rpms VERSION=$(VERSION) RPM_OS=$$distro && \
	  find rabbitmq-server/packaging/RPMS/Fedora -name "*.rpm" -exec cp '{}' $(SERVER_PACKAGES_DIR) ';' ; \
	done

# This target ssh's into the OSX host in order to finalize the
# macports repo, so it is not invoked by rabbitmq-server-artifacts.
# Note that the "clean" below is significant: Because the REAL_WEB_URL
# environment variable might change, we need to rebuild the macports
# artifacts at each deploy.
.PHONY: rabbitmq-server-macports-packaging
rabbitmq-server-macports-packaging:
	$(MAKE) -C rabbitmq-server/packaging/macports clean macports VERSION=$(VERSION)
	cp -r rabbitmq-server/packaging/macports/macports $(PACKAGES_DIR)


.PHONY: rabbitmq-java-artifacts
rabbitmq-java-artifacts: prepare
	$(MAKE) -C rabbitmq-java-client dist VERSION=$(VERSION)
	mkdir -p $(JAVA_CLIENT_PACKAGES_DIR)
	cp rabbitmq-java-client/build/*.tar.gz $(JAVA_CLIENT_PACKAGES_DIR)
	cp rabbitmq-java-client/build/*.zip $(JAVA_CLIENT_PACKAGES_DIR)
	cd $(JAVA_CLIENT_PACKAGES_DIR); unzip -q rabbitmq-java-client-javadoc-$(VERSION).zip


.PHONY: rabbitmq-dotnet-artifacts
rabbitmq-dotnet-artifacts: prepare
	$(MAKE) -C rabbitmq-dotnet-client dist RABBIT_VSN=$(VERSION)
	mkdir -p $(DOTNET_CLIENT_PACKAGES_DIR)
	cp -a rabbitmq-dotnet-client/release/* $(DOTNET_CLIENT_PACKAGES_DIR)


.PHONY: rabbitmq-erlang-client-artifacts
rabbitmq-erlang-client-artifacts: prepare
	$(MAKE) -C rabbitmq-public-umbrella/rabbitmq-erlang-client distribution VERSION=$(VERSION)
	mkdir -p $(ERLANG_CLIENT_PACKAGES_DIR)
	cp rabbitmq-public-umbrella/rabbitmq-erlang-client/dist/*.ez $(ERLANG_CLIENT_PACKAGES_DIR)
	cp rabbitmq-public-umbrella/rabbitmq-erlang-client/dist/*.tar.gz $(ERLANG_CLIENT_PACKAGES_DIR)
	cp -r rabbitmq-public-umbrella/rabbitmq-erlang-client/doc/ $(ERLANG_CLIENT_PACKAGES_DIR)


.PHONY: rabbitmq-public-umbrella-artifacts
rabbitmq-public-umbrella-artifacts:
	$(MAKE) -C rabbitmq-public-umbrella plugins-dist PLUGINS_DIST_DIR=$(ABSOLUTE_PLUGINS_DIR) VERSION=$(VERSION)

.PHONY: rabbitmq-public-umbrella-srcdist
rabbitmq-public-umbrella-srcdist:
	$(MAKE) -C rabbitmq-public-umbrella plugins-srcdist PLUGINS_SRC_DIST_DIR=$(ABSOLUTE_PLUGINS_SRC_DIR) VERSION=$(VERSION)

.PHONY: sign-artifacts
ifneq "$(UNOFFICIAL_RELEASE)" ""
sign-artifacts:
	true
else
sign-artifacts: artifacts
	python util/nopassphrase.py \
            rpm --addsign \
		--define '_signature gpg' \
		--define '_gpg_path $(GNUPG_PATH)/.gnupg/' \
		--define '_gpg_name $(SIGNING_USER_ID)' \
		$(PACKAGES_DIR)/*/*/*.rpm
	for p in \
		$(SERVER_PACKAGES_DIR)/* \
		$(JAVA_CLIENT_PACKAGES_DIR)/* \
		$(ERLANG_CLIENT_PACKAGES_DIR)/* \
	; do \
		[ -f $$p ] && \
			HOME=$(GNUPG_PATH) gpg --default-key $(SIGNING_KEY) -abs -o $$p.asc $$p ; \
	done
endif

###########################################################################

DEPLOY_HOST=localhost
DEPLOY_PATH=/tmp/rabbitmq/extras/releases
DEPLOY_DEST=$(DEPLOY_HOST):$(DEPLOY_PATH)

RSYNC_CMD=rsync -rpl --delete-after

DEPLOYMENT_SUBDIRECTORIES=rabbitmq-server rabbitmq-java-client rabbitmq-dotnet-client rabbitmq-erlang-client

DEPLOY_RSYNC_CMDS=\
	set -x -e; \
	for subdirectory in $(DEPLOYMENT_SUBDIRECTORIES) ; do \
		ssh $(SSH_OPTS) $(DEPLOY_HOST) "(cd $(DEPLOY_PATH); if [ ! -d $$subdirectory ] ; then mkdir -p $$subdirectory; chmod g+w $$subdirectory; fi)"; \
		$(RSYNC_CMD) $(PACKAGES_DIR)/$$subdirectory/* \
		    $(DEPLOY_DEST)/$$subdirectory ; \
	done; \
	for subdirectory in debian macports ; do \
		$(RSYNC_CMD) $(PACKAGES_DIR)/$$subdirectory \
	    	    $(DEPLOY_DEST); \
	done; \
	unpacked_javadoc_dir=`(cd packages/rabbitmq-java-client; ls -td */rabbitmq-java-client-javadoc-*/ | head -1)`; \
	ssh $(SSH_OPTS) $(DEPLOY_HOST) "(cd $(DEPLOY_PATH)/rabbitmq-java-client; rm -f current-javadoc; ln -s $$unpacked_javadoc_dir current-javadoc)"; \
	ssh $(SSH_OPTS) $(DEPLOY_HOST) "(cd $(DEPLOY_PATH)/rabbitmq-server; rm -f current; ln -s $(VDIR) current)"; \

deploy: verify-signatures fixup-permissions-for-deploy
	$(DEPLOY_RSYNC_CMDS)

deploy-live: verify-signatures deploy-maven fixup-permissions-for-deploy
	$(DEPLOY_RSYNC_CMDS)

fixup-permissions-for-deploy:
	chmod -R g+w $(PACKAGES_DIR)
	chmod g+s `find $(PACKAGES_DIR) -type d`

verify-signatures:
	for file in `find $(PACKAGES_DIR) -type f -name "*.asc"`; do \
	    echo "Checking $$file" ; \
	    if ! HOME=$(GNUPG_PATH) gpg --verify $$file `echo $$file | sed -e 's/\.asc$$//'`; then \
	        bad_signature=1 ; \
	    fi ; \
	done ; \
	[ -z "$$bad_signature" ]

deploy-maven: verify-signatures
	$(MAKE) -C rabbitmq-java-client stage-and-promote-maven-bundle SIGNING_KEY=$(SIGNING_KEY) VERSION=$(VERSION) GNUPG_PATH=$(GNUPG_PATH)
