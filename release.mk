# This is a TEMPORARY umbrella makefile, that will likely not survive
# the repo split.

VERSION=0.0.0
VDIR=v$(VERSION)
TAG=rabbitmq_$(subst .,_,$(VDIR))

SIGNING_KEY=056E8E56
SIGNING_USER_EMAIL=info@rabbitmq.com
SIGNING_USER_ID=RabbitMQ Release Signing Key <info@rabbitmq.com>

# Misc options to pass to hg commands
HG_OPTS=

# Misc options to pass to ssh commands

PACKAGES_DIR=packages

SERVER_PACKAGES_DIR=$(PACKAGES_DIR)/rabbitmq-server/$(VDIR)
JAVA_CLIENT_PACKAGES_DIR=$(PACKAGES_DIR)/rabbitmq-java-client/$(VDIR)
DOTNET_CLIENT_PACKAGES_DIR=$(PACKAGES_DIR)/rabbitmq-dotnet-client/$(VDIR)
BUNDLES_PACKAGES_DIR=$(PACKAGES_DIR)/bundles/$(VDIR)

REQUIRED_EMULATOR_VERSION=5.6.3
ACTUAL_EMULATOR_VERSION=$(shell erl -noshell -eval 'io:format("~s",[erlang:system_info(version)]),init:stop().')

REPOS=rabbitmq-codegen rabbitmq-server rabbitmq-java-client rabbitmq-dotnet-client

HGREPOBASE:=$(shell dirname `hg paths default 2>/dev/null` 2>/dev/null)

ifeq ($(HGREPOBASE),)
HGREPOBASE=ssh://hg@hg.rabbitmq.com
endif

.PHONY: packages website_manpages

all:
	@echo Please choose a target from the Makefile.

checkout: $(REPOS)

tag: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg tag $(TAG));)

push: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg push $(HG_OPTS) -f);)

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
		echo "Alternatively, set the makefile variable REQUIRED_EMULATOR_VERSION=$(ACTUAL_EMULATOR_VERSION) ."; \
		[ -n "$(UNOFFICIAL_RELEASE)" ] )
	@echo Checking the presence of the tools necessary to build a release on a Debian based OS.
	dpkg -L cdbs elinks fakeroot findutils gnupg gzip perl python python-simplejson rpm rsync wget reprepro tar tofrodos zip python-pexpect s3cmd openssl xmlto xsltproc > /dev/null
	@echo All required tools are installed, great!
	mkdir -p $(PACKAGES_DIR)
	mkdir -p $(SERVER_PACKAGES_DIR)
	mkdir -p $(JAVA_CLIENT_PACKAGES_DIR)
	mkdir -p $(DOTNET_CLIENT_PACKAGES_DIR)
	mkdir -p $(BUNDLES_PACKAGES_DIR)

packages: prepare
	$(MAKE) $(SERVER_PACKAGES_DIR)/rabbitmq-server-$(VERSION).tar.gz
	$(MAKE) $(SERVER_PACKAGES_DIR)/rabbitmq-server-$(VERSION).zip
	$(MAKE) $(SERVER_PACKAGES_DIR)/rabbitmq-server-generic-unix-$(VERSION).tar.gz
	$(MAKE) $(SERVER_PACKAGES_DIR)/rabbitmq-server-windows-$(VERSION).zip
	$(MAKE) website_manpages
	$(MAKE) debian_packages
	$(MAKE) rpm_packages
	$(MAKE) java_packages
	$(MAKE) dotnet_packages

ifneq "$(UNOFFICIAL_RELEASE)" ""
sign_everything:
	true
else
sign_everything:
	python util/nopassphrase.py \
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

$(SERVER_PACKAGES_DIR)/rabbitmq-server-$(VERSION).tar.gz: rabbitmq-server
	$(MAKE) -C rabbitmq-server clean srcdist VERSION=$(VERSION)
	cp rabbitmq-server/dist/rabbitmq-server-*.tar.gz $(SERVER_PACKAGES_DIR)

$(SERVER_PACKAGES_DIR)/rabbitmq-server-$(VERSION).zip: rabbitmq-server
	$(MAKE) -C rabbitmq-server clean srcdist VERSION=$(VERSION)
	cp rabbitmq-server/dist/rabbitmq-server-*.zip $(SERVER_PACKAGES_DIR)

$(SERVER_PACKAGES_DIR)/rabbitmq-server-generic-unix-$(VERSION).tar.gz: rabbitmq-server
	$(MAKE) -C rabbitmq-server/packaging/generic-unix clean dist VERSION=$(VERSION)
	cp rabbitmq-server/packaging/generic-unix/rabbitmq-server-generic-unix-*.tar.gz $(SERVER_PACKAGES_DIR)

$(SERVER_PACKAGES_DIR)/rabbitmq-server-windows-$(VERSION).zip: rabbitmq-server
	$(MAKE) -C rabbitmq-server/packaging/windows clean dist VERSION=$(VERSION)
	cp rabbitmq-server/packaging/windows/rabbitmq-server-windows-*.zip $(SERVER_PACKAGES_DIR)

website_manpages: rabbitmq-server
	$(MAKE) -C rabbitmq-server docs_all VERSION=$(VERSION)
	cp rabbitmq-server/docs/*.man.xml $(SERVER_PACKAGES_DIR)

debian_packages: $(SERVER_PACKAGES_DIR)/rabbitmq-server-$(VERSION).tar.gz rabbitmq-server
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

rpm_packages: $(SERVER_PACKAGES_DIR)/rabbitmq-server-$(VERSION).tar.gz rabbitmq-server
	for distro in fedora suse ; do \
	  $(MAKE) -C rabbitmq-server/packaging/RPMS/Fedora rpms VERSION=$(VERSION) RPM_OS=$$distro && \
	  find rabbitmq-server/packaging/RPMS/Fedora -name "*.rpm" -exec cp '{}' $(SERVER_PACKAGES_DIR) ';' ; \
	done

# This target ssh's into the OSX host in order to finalize the
# macports repo, so it is not invoked by packages
macports: $(SERVER_PACKAGES_DIR)/rabbitmq-server-$(VERSION).tar.gz rabbitmq-server
	$(MAKE) -C rabbitmq-server/packaging/macports clean macports VERSION=$(VERSION)
	cp -r rabbitmq-server/packaging/macports/macports $(PACKAGES_DIR)

java_packages: rabbitmq-java-client
	$(MAKE) -C rabbitmq-java-client clean dist VERSION=$(VERSION)
	cp rabbitmq-java-client/build/*.tar.gz $(JAVA_CLIENT_PACKAGES_DIR)
	cp rabbitmq-java-client/build/*.zip $(JAVA_CLIENT_PACKAGES_DIR)
	cd $(JAVA_CLIENT_PACKAGES_DIR); unzip rabbitmq-java-client-javadoc-$(VERSION).zip

dotnet_packages:
	$(MAKE) -C rabbitmq-dotnet-client dist RABBIT_VSN=$(VERSION)
	cp -a rabbitmq-dotnet-client/release/* $(DOTNET_CLIENT_PACKAGES_DIR)

WINDOWS_BUNDLE_TMP_DIR=$(PACKAGES_DIR)/complete-rabbitmq-bundle-$(VERSION)
windows_bundle:
	rm -rf $(WINDOWS_BUNDLE_TMP_DIR)
	mkdir -p $(WINDOWS_BUNDLE_TMP_DIR)
	[ -f /tmp/otp_win32_R13B03.exe ] || \
		wget -P /tmp http://erlang.org/download/otp_win32_R13B03.exe
	cp /tmp/otp_win32_R13B03.exe $(WINDOWS_BUNDLE_TMP_DIR)
	cp \
		$(SERVER_PACKAGES_DIR)/rabbitmq-server-windows-$(VERSION).zip \
		$(JAVA_CLIENT_PACKAGES_DIR)/rabbitmq-java-client-bin-$(VERSION).zip \
		$(DOTNET_CLIENT_PACKAGES_DIR)/rabbitmq-dotnet-client-$(VERSION).msi \
		$(WINDOWS_BUNDLE_TMP_DIR)
	cp ./README-windows-bundle $(WINDOWS_BUNDLE_TMP_DIR)/README
	sed -i 's/%%VERSION%%/$(VERSION)/' $(WINDOWS_BUNDLE_TMP_DIR)/README
	(cd $(WINDOWS_BUNDLE_TMP_DIR)/..; \
		zip -r complete-rabbitmq-bundle-$(VERSION).zip complete-rabbitmq-bundle-$(VERSION);)
	mv $(WINDOWS_BUNDLE_TMP_DIR)/../complete-rabbitmq-bundle-$(VERSION).zip \
		$(BUNDLES_PACKAGES_DIR)
	rm -rf $(WINDOWS_BUNDLE_TMP_DIR)

rabbitmq-server: rabbitmq-codegen
	[ -d $@ ] || hg clone $(HG_OPTS) $(HGREPOBASE)/$@

rabbitmq-java-client: rabbitmq-codegen
	[ -d $@ ] || hg clone $(HG_OPTS) $(HGREPOBASE)/$@

rabbitmq-dotnet-client:
	[ -d $@ ] || hg clone $(HG_OPTS) $(HGREPOBASE)/$@

rabbitmq-codegen:
	[ -d $@ ] || hg clone $(HG_OPTS) $(HGREPOBASE)/$@

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

LIVE_DEPLOY_HOST=www
LIVE_DEPLOY_PATH=/home/rabbitmq/extras

STAGE_DEPLOY_HOST=www-stage
STAGE_DEPLOY_PATH=/home/rabbitmq/extras

RSYNC_CMD=rsync -irvpl --delete-after

DEPLOY_RSYNC_CMDS=\
	set -x -e; \
	for subdirectory in rabbitmq-server rabbitmq-java-client rabbitmq-dotnet-client bundles; do \
		ssh $(SSH_OPTS) $$deploy_host "(cd $$deploy_path/releases; if [ ! -d $$subdirectory ] ; then mkdir -p $$subdirectory; chmod g+w $$subdirectory; fi)"; \
		$(RSYNC_CMD) $(PACKAGES_DIR)/$$subdirectory/* \
		    $$deploy_host:$$deploy_path/releases/$$subdirectory ; \
	done; \
	for subdirectory in debian macports ; do \
		$(RSYNC_CMD) $(PACKAGES_DIR)/$$subdirectory \
	    	    $$deploy_host:$$deploy_path/releases; \
	done; \
	unpacked_javadoc_dir=`(cd packages/rabbitmq-java-client; ls -td */rabbitmq-java-client-javadoc-*/ | head -1)`; \
	ssh $(SSH_OPTS) $$deploy_host "(cd $$deploy_path/releases/rabbitmq-java-client; rm -f current-javadoc; ln -s $$unpacked_javadoc_dir current-javadoc)"; \
	ssh $(SSH_OPTS) $$deploy_host "(cd $$deploy_path/releases/rabbitmq-server; ln -sf $(VDIR) current)"; \

deploy-stage: fixup-permissions-for-deploy
	deploy_host=$(STAGE_DEPLOY_HOST); \
	     deploy_path=$(STAGE_DEPLOY_PATH); \
	     $(DEPLOY_RSYNC_CMDS)
	$(MAKE) -C rabbitmq-java-client stage-maven-bundle SIGNING_KEY=$(SIGNING_KEY) VERSION=$(VERSION) GNUPG_PATH=$(GNUPG_PATH)

deploy-live: fixup-permissions-for-deploy deploy-cloudfront cloudfront-verify
	deploy_host=$(LIVE_DEPLOY_HOST); \
	     deploy_path=$(LIVE_DEPLOY_PATH); \
	     $(DEPLOY_RSYNC_CMDS)
	$(MAKE) -C rabbitmq-java-client promote-maven-bundle GNUPG_PATH=$(GNUPG_PATH)


fixup-permissions-for-deploy:
	chmod -R g+w $(PACKAGES_DIR)
	chmod g+s `find $(PACKAGES_DIR) -type d`

# The major problem with CloudFront is that they _don't see updates_!
# So you can upload stuff to CF only once, never reuse the same filenames.
# That's why we are interested only in deploy-live.
S3CMD_CONF=$(GNUPG_PATH)/../s3cmd-cloudfront-amazon-aws
S3_BUCKET=s3://rabbitmq-mirror
CF_URL=http://mirror.rabbitmq.com
## Mirror behaves badly if the data was changed. To force script to continue
## in such case, set this path to s3 bucket path:
# CF_URL=http://s3.amazonaws.com/rabbitmq-mirror

# Deploys the contents of $(SERVER_PACKAGES_DIR) to cloudfront.
# Hopefully all the files contain a rabbitmq version in the name.
#  We do have to iterate through every file, as for buggy s3cmd.
SUBDIRECTORIES=rabbitmq-server rabbitmq-java-client rabbitmq-dotnet-client bundles
deploy-cloudfront: $(S3CMD_CONF)
	cd $(PACKAGES_DIR);	\
	VSUBDIRS=`for subdir in $(SUBDIRECTORIES); do echo $$subdir/$(VDIR); done`;	\
	for file in `find $$VSUBDIRS -maxdepth 1 -type f|egrep -v '.asc$$'`; do	\
		DST=$(S3_BUCKET)/releases/$$file; 	\
		s3cmd put				\
			--bucket-location=EU		\
			--acl-public			\
			--force				\
			--no-preserve			\
			--config=$(S3CMD_CONF)		\
				$$file $$DST;		\
	done;


cloudfront-verify:
	@echo " [*] Verifying Cloudfront uploads"
	cd $(PACKAGES_DIR);	\
	VSUBDIRS=`for subdir in $(SUBDIRECTORIES); do echo $$subdir/$(VDIR); done`;	\
	for file in `find $$VSUBDIRS -maxdepth 1 -type f|egrep -v '.asc$$'`; do	\
		URL=$(CF_URL)/releases/$$file; \
		echo -en "$$file\t"; \
		A=`md5sum $$file | awk '{print $$1}'`; \
		rm -f $$file.fetched; \
		wget $$URL -O $$file.fetched; \
		B=`md5sum $$file.fetched  | awk '{print $$1}'`; \
		echo $$A $$B; \
		ls -l $$file $$file.fetched; \
		rm -f $$file.fetched; \
		if [ "$$A" != "$$B" ]; then			\
			echo "BAD CLOUDFRONT CHECKSUM FOR $$URL"; \
			exit 1;					\
		else						\
			echo "ok!";				\
		fi						\
	done


$(S3CMD_CONF):
	@[ "`ls $(S3CMD_CONF) 2>/dev/null`" != "" ] || \
		(echo "You need s3 access keys!"; \
		 echo "Run: s3cmd --config=$(S3CMD_CONF) --configure"; \
	 		false)
