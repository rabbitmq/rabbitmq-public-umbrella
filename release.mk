# This is a TEMPORARY umbrella makefile, that will likely not survive
# the repo split.

VERSION=0.0.0
VDIR=v$(VERSION)

SIGNING_KEY=056E8E56
SIGNING_USER_EMAIL=info@rabbitmq.com
SIGNING_USER_ID=RabbitMQ Release Signing Key <info@rabbitmq.com>

PACKAGES_DIR=packages

SERVER_PACKAGES_DIR=$(PACKAGES_DIR)/rabbitmq-server/$(VDIR)
JAVA_CLIENT_PACKAGES_DIR=$(PACKAGES_DIR)/rabbitmq-java-client/$(VDIR)
BUNDLES_PACKAGES_DIR=$(PACKAGES_DIR)/bundles/$(VDIR)

REQUIRED_EMULATOR_VERSION=5.5.5
ACTUAL_EMULATOR_VERSION=$(shell erl -noshell -eval 'io:format("~s",[erlang:system_info(version)]),init:stop().')

HGREPOBASE:=$(shell dirname `hg paths default 2>/dev/null` 2>/dev/null)

ifeq ($(HGREPOBASE),)
HGREPOBASE=ssh://hg@hg.lshift.net
endif

.PHONY: packages

all:
	@echo Please choose a target from the Makefile.

checkout: rabbitmq-codegen rabbitmq-server rabbitmq-java-client

ifeq "$(UNOFFICIAL_RELEASE)$(GNUPG_PATH)" ""
dist:
	@echo "You must specify one of UNOFFICIAL_RELEASE (to true, if you don't want to sign packages) or GNUPG_PATH (to the location of the RabbitMQ keyring) when making dist."
	@false
else
dist: packages bundles sign_everything
endif

prepare:
	@[ "$(REQUIRED_EMULATOR_VERSION)" = "$(ACTUAL_EMULATOR_VERSION)" ] || \
		(echo "You are trying to compile with the wrong Erlang/OTP release."; \
		echo "Please use emulator version $(REQUIRED_EMULATOR_VERSION)."; \
		false)
	@echo Checking the presence of the tools necessary to build a release on a Debian based OS.
	dpkg -L cdbs elinks findutils gnupg gzip perl python python-json rpm rsync wget reprepro tar zip > /dev/null
	@echo All required tools are installed, great!
	mkdir -p $(PACKAGES_DIR)
	mkdir -p $(SERVER_PACKAGES_DIR)
	mkdir -p $(JAVA_CLIENT_PACKAGES_DIR)
	mkdir -p $(BUNDLES_PACKAGES_DIR)

packages: prepare
	$(MAKE) $(SERVER_PACKAGES_DIR)/rabbitmq-server-$(VERSION).tar.gz
	$(MAKE) $(SERVER_PACKAGES_DIR)/rabbitmq-server-$(VERSION).zip
	$(MAKE) $(SERVER_PACKAGES_DIR)/rabbitmq-server-generic-unix-$(VERSION).tar.gz
	$(MAKE) $(SERVER_PACKAGES_DIR)/rabbitmq-server-windows-$(VERSION).zip
	$(MAKE) debian_packages
	$(MAKE) rpm_packages
	$(MAKE) java_packages

ifneq "$(UNOFFICIAL_RELEASE)" ""
sign_everything:
	true
else
sign_everything:
	rpm --addsign \
		--define '_signature gpg' \
		--define '_gpg_path $(GNUPG_PATH)/.gnupg/' \
		--define '_gpg_name $(SIGNING_USER_ID)' \
		$(PACKAGES_DIR)/*/*/*.rpm
	for p in \
		$(SERVER_PACKAGES_DIR)/* \
		$(JAVA_CLIENT_PACKAGES_DIR)/* \
		$(BUNDLES_PACKAGES_DIR)/* \
	; do \
		[ -f $$p ] && \
			HOME=$(GNUPG_PATH) gpg --default-key $(SIGNING_KEY) -abs -o $$p.asc $$p ; \
	done
endif

bundles: packages
	$(MAKE) windows_bundle

$(SERVER_PACKAGES_DIR)/rabbitmq-server-$(VERSION).tar.gz: prepare rabbitmq-server
	$(MAKE) -C rabbitmq-server clean srcdist VERSION=$(VERSION)
	cp rabbitmq-server/dist/rabbitmq-server-*.tar.gz $(SERVER_PACKAGES_DIR)

$(SERVER_PACKAGES_DIR)/rabbitmq-server-$(VERSION).zip: prepare rabbitmq-server
	$(MAKE) -C rabbitmq-server clean srcdist VERSION=$(VERSION)
	cp rabbitmq-server/dist/rabbitmq-server-*.zip $(SERVER_PACKAGES_DIR)

$(SERVER_PACKAGES_DIR)/rabbitmq-server-generic-unix-$(VERSION).tar.gz: prepare rabbitmq-server
	$(MAKE) -C rabbitmq-server/packaging/generic-unix clean dist VERSION=$(VERSION)
	cp rabbitmq-server/packaging/generic-unix/rabbitmq-server-generic-unix-*.tar.gz $(SERVER_PACKAGES_DIR)

$(SERVER_PACKAGES_DIR)/rabbitmq-server-windows-$(VERSION).zip: prepare rabbitmq-server
	$(MAKE) -C rabbitmq-server/packaging/windows clean dist VERSION=$(VERSION)
	cp rabbitmq-server/packaging/windows/rabbitmq-server-windows-*.zip $(SERVER_PACKAGES_DIR)

debian_packages: prepare $(SERVER_PACKAGES_DIR)/rabbitmq-server-$(VERSION).tar.gz rabbitmq-server
	$(MAKE) -C rabbitmq-server/packaging/debs/Debian clean package \
		UNOFFICIAL_RELEASE=$(UNOFFICIAL_RELEASE) \
		GNUPG_PATH=$(GNUPG_PATH) \
		VERSION=$(VERSION) \
		SIGNING_KEY_ID=$(SIGNING_KEY)
	cp rabbitmq-server/packaging/debs/Debian/rabbitmq-server*$(VERSION)*.deb $(SERVER_PACKAGES_DIR)
	cp rabbitmq-server/packaging/debs/Debian/rabbitmq-server*$(VERSION)*.diff.gz $(SERVER_PACKAGES_DIR)
	cp rabbitmq-server/packaging/debs/Debian/rabbitmq-server*$(VERSION)*.orig.tar.gz $(SERVER_PACKAGES_DIR)
	cp rabbitmq-server/packaging/debs/Debian/rabbitmq-server*$(VERSION)*.dsc $(SERVER_PACKAGES_DIR)
	$(MAKE) -C rabbitmq-server/packaging/debs/apt-repository all \
		UNOFFICIAL_RELEASE=$(UNOFFICIAL_RELEASE) \
		GNUPG_PATH=$(GNUPG_PATH) \
		SIGNING_USER_EMAIL=$(SIGNING_USER_EMAIL)
	cp -r rabbitmq-server/packaging/debs/apt-repository/debian $(PACKAGES_DIR)

rpm_packages: prepare $(SERVER_PACKAGES_DIR)/rabbitmq-server-$(VERSION).tar.gz rabbitmq-server
	$(MAKE) -C rabbitmq-server/packaging/RPMS/Fedora rpms VERSION=$(VERSION)
	cp rabbitmq-server/packaging/RPMS/Fedora/RPMS/i386/rabbitmq-server*.rpm $(SERVER_PACKAGES_DIR)
	cp rabbitmq-server/packaging/RPMS/Fedora/RPMS/x86_64/rabbitmq-server*.rpm $(SERVER_PACKAGES_DIR)

java_packages: prepare rabbitmq-java-client
	$(MAKE) -C rabbitmq-java-client clean dist VERSION=$(VERSION)
	cp rabbitmq-java-client/build/*.tar.gz $(JAVA_CLIENT_PACKAGES_DIR)
	cp rabbitmq-java-client/build/*.zip $(JAVA_CLIENT_PACKAGES_DIR)
	cd $(JAVA_CLIENT_PACKAGES_DIR); unzip rabbitmq-java-client-javadoc-$(VERSION).zip

WINDOWS_BUNDLE_TMP_DIR=$(PACKAGES_DIR)/complete-rabbitmq-bundle-$(VERSION)
windows_bundle:
	rm -rf $(WINDOWS_BUNDLE_TMP_DIR)
	mkdir -p $(WINDOWS_BUNDLE_TMP_DIR)
	[ -f /tmp/otp_win32_R11B-5.exe ] || \
		wget -P /tmp http://www.erlang.org/download/otp_win32_R11B-5.exe
	cp /tmp/otp_win32_R11B-5.exe $(WINDOWS_BUNDLE_TMP_DIR)
	cp \
		$(SERVER_PACKAGES_DIR)/rabbitmq-server-windows-$(VERSION).zip \
		$(JAVA_CLIENT_PACKAGES_DIR)/rabbitmq-java-client-bin-$(VERSION).zip \
		$(WINDOWS_BUNDLE_TMP_DIR)
	cp ./README-windows-bundle $(WINDOWS_BUNDLE_TMP_DIR)/README
	sed -i 's/%%VERSION%%/$(VERSION)/' $(WINDOWS_BUNDLE_TMP_DIR)/README
	(cd $(WINDOWS_BUNDLE_TMP_DIR)/..; \
		zip -r complete-rabbitmq-bundle-$(VERSION).zip complete-rabbitmq-bundle-$(VERSION);)
	mv $(WINDOWS_BUNDLE_TMP_DIR)/../complete-rabbitmq-bundle-$(VERSION).zip \
		$(BUNDLES_PACKAGES_DIR)
	rm -rf $(WINDOWS_BUNDLE_TMP_DIR)

rabbitmq-server: rabbitmq-codegen
	[ -d $@ ] || hg clone $(HGREPOBASE)/$@

rabbitmq-java-client: rabbitmq-codegen
	[ -d $@ ] || hg clone $(HGREPOBASE)/$@

rabbitmq-codegen:
	[ -d $@ ] || hg clone $(HGREPOBASE)/$@

clean:
	rm -rf $(PACKAGES_DIR)
	$(MAKE) -C rabbitmq-server clean
	$(MAKE) -C rabbitmq-server/packaging/generic-unix clean
	$(MAKE) -C rabbitmq-server/packaging/windows clean
	$(MAKE) -C rabbitmq-server/packaging/debs/Debian clean
	$(MAKE) -C rabbitmq-server/packaging/debs/apt-repository clean
	$(MAKE) -C rabbitmq-server/packaging/RPMS/Fedora clean
	$(MAKE) -C rabbitmq-java-client clean

###########################################################################

RSYNC_CMD=rsync -irvpl
DEPLOY_HOST=charlotte

DEPLOY_RSYNC_CMDS=\
	set -x; \
	for subdirectory in rabbitmq-server rabbitmq-java-client bundles; do \
		ssh $(DEPLOY_HOST) "(cd $${DEPLOY_ROOT}/releases; mkdir -p $$subdirectory; chmod g+w $$subdirectory)"; \
		$(RSYNC_CMD) --delete-after $(PACKAGES_DIR)/$$subdirectory/* \
			$(DEPLOY_HOST):$${DEPLOY_ROOT}/releases/$$subdirectory ; \
	done; \
	$(RSYNC_CMD) --delete-after \
			$(PACKAGES_DIR)/debian \
		$(DEPLOY_HOST):$${DEPLOY_ROOT}/releases; \
	UNPACKED_JAVADOC_DIR=`(cd packages/rabbitmq-java-client; ls -td */rabbitmq-java-client-javadoc-*/ | head -1)`; \
	ssh $(DEPLOY_HOST) "(cd $${DEPLOY_ROOT}/releases/rabbitmq-java-client; rm -f current-javadoc; ln -s $${UNPACKED_JAVADOC_DIR} current-javadoc)"; \
	set +x

deploy-stage: fixup-permissions-for-deploy
	(DEPLOY_ROOT=/home/rabbitmq/stage-extras; $(DEPLOY_RSYNC_CMDS))

deploy-live: fixup-permissions-for-deploy
	(DEPLOY_ROOT=/home/rabbitmq/live-extras; $(DEPLOY_RSYNC_CMDS))

fixup-permissions-for-deploy:
	chmod -R g+w $(PACKAGES_DIR)
	chmod g+s `find $(PACKAGES_DIR) -type d`
