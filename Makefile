PROJECT = rabbitmq_public_umbrella

DEPS = $(RABBITMQ_COMPONENTS)

.DEFAULT_GOAL = up

DEP_PLUGINS = rabbit_common/mk/rabbitmq-run.mk \
	      rabbit_common/mk/rabbitmq-tools.mk

# FIXME: Use erlang.mk patched for RabbitMQ, while waiting for PRs to be
# reviewed and merged.

ERLANG_MK_REPO = https://github.com/rabbitmq/erlang.mk.git
ERLANG_MK_COMMIT = rabbitmq-tmp

include rabbitmq-components.mk
include erlang.mk

.PHONY: co up status clean-subrepos distclean-subrepos

# make co: legacy target.
co: fetch-deps
	@:

up: $(abspath .)+up $(DEPS:%=$(DEPS_DIR)/%+up)
	@:

%+up: fetch-deps
	$(exec_verbose) cd $*; \
	git fetch -p && \
	if [ '$(BRANCH)' ]; then \
		git checkout $(BRANCH) || : ; \
	fi && \
	if git symbolic-ref -q HEAD >/dev/null; then \
		branch=$$(git symbolic-ref --short HEAD); \
		remote=$$(git config branch.$$branch.remote); \
		merge=$$(git config branch.$$branch.merge | sed 's,refs/heads/,,'); \
		if [ "$$remote" -a "$$merge" ]; then \
			git merge --ff-only "$$remote/$$merge"; \
		fi; \
	fi && \
	echo

status: $(abspath .)+status $(READY_DEPS:%=$(DEPS_DIR)/%+status)
	@:

%+status:
	$(exec_verbose) cd $*; \
	git status -s && \
	echo

push: $(abspath .)+push $(READY_DEPS:%=$(DEPS_DIR)/%+push)
	@:

%+push:
	$(exec_verbose) cd $*; \
        git pull && \
	git push && \
	git push --tags --force && \
	echo

tag: $(abspath .)+tag $(READY_DEPS:%=$(DEPS_DIR)/%+tag)
	@:

%+tag:
	$(exec_verbose) test "$(TAG)" || (printf "\nERROR: TAG must be set\n\n" 1>&2; false)
	$(verbose) cd $*; \
	git pull --ff && \
	git tag $(TAG) && \
	echo

clean:: clean-subrepos

clean-subrepos: $(READY_DEPS:%=$(DEPS_DIR)/%+clean)
	@:

%+clean:
	-$(exec_verbose) $(MAKE) -C $* clean

distclean:: distclean-subrepos

distclean-subrepos: $(READY_DEPS:%=$(DEPS_DIR)/%+distclean)
	@:

%+distclean:
	-$(exec_verbose) $(MAKE) -C $* distclean

# --------------------------------------------------------------------
# Release engineering.
# --------------------------------------------------------------------

VERSION ?= 0.0.0
PACKAGES_DIR ?= packages
SERVER_PACKAGES_DIR ?= $(PACKAGES_DIR)/rabbitmq-server/v$(VERSION)
JAVA_CLIENT_PACKAGES_DIR ?= $(PACKAGES_DIR)/rabbitmq-java-client/v$(VERSION)
DOTNET_CLIENT_PACKAGES_DIR ?= $(PACKAGES_DIR)/rabbitmq-dotnet-client/v$(VERSION)
ERLANG_CLIENT_PACKAGES_DIR ?= $(PACKAGES_DIR)/rabbitmq-erlang-client/v$(VERSION)
CLIENTS_BUILD_DOC_DIR ?= $(PACKAGES_DIR)/clients-build-doc/v$(VERSION)
DEBIAN_REPO_DIR ?= $(PACKAGES_DIR)/debian

UNIX_HOST ?=
MACOSX_HOST ?=
WINDOWS_HOST ?=

SIGNING_KEY ?= 056E8E56
SIGNING_USER_EMAIL ?= info@rabbitmq.com
SIGNING_USER_ID ?= RabbitMQ Release Signing Key <info@rabbitmq.com>

ifneq ($(KEYSDIR),)
ifeq ($(UNIX_HOST),)
SIGNING_VARS += GNUPG_PATH=$(abspath $(KEYSDIR)/keyring)
else ifeq ($(UNIX_HOST),localhost)
SIGNING_VARS += GNUPG_PATH=$(abspath $(KEYSDIR)/keyring)
else
SIGNING_SRCS += $(KEYSDIR)/keyring
SIGNING_VARS += GNUPG_PATH="$$HOME/$(REMOTE_RELEASE_TMPDIR)/keyring"
endif

SIGNING_VARS += SIGNING_KEY="$(SIGNING_KEY)" \
		SIGNING_USER_ID="$(SIGNING_USER_ID)" \
		SIGNING_USER_EMAIL="$(SIGNING_USER_EMAIL)"
endif

SSH_OPTS ?=

# The name and email address to use in package changelog entries.
CHANGELOG_NAME ?= RabbitMQ Team
CHANGELOG_EMAIL ?= packaging@rabbitmq.com

# The revision of Debian and RPM packages.
CHANGELOG_PKG_REV ?= 1

# The comment for changelog entries.
CHANGELOG_COMMENT ?= New upstream release
CHANGELOG_ADDITIONAL_COMMENTS_FILE ?= \
	$(DEPS_DIR)/rabbit/packaging/debs/Debian/changelog_comments/additional_changelog_comments_$(VERSION)

OTP_VERSION ?= R16B03
STANDALONE_OTP_VERSION ?= 17.5

SOURCE_DIST_FILE = $(SERVER_PACKAGES_DIR)/rabbitmq-server-$(VERSION).tar.xz

REMOTE_MAKE ?= $(MAKE)

RSYNC ?= rsync
RSYNC_V_0 =
RSYNC_V_1 = -v
RSYNC_V_2 = -v
RSYNC_V = $(RSYNC_V_$(V))
RSYNC_FLAGS = -a $(RSYNC_V) \
	      --exclude '.sw?' --exclude '.*.sw?'	\
	      --exclude '.git*'				\
	      --exclude '.hg*'				\
	      --exclude '.travis.yml'

.PHONY: release release-source-dist release-server release-clients

release: release-server release-clients
	@:

release-server: release-server-sources
	@:

release-clients:
	@:

release-server-sources: $(DEPS_DIR)/rabbit
# Prepare changelog entries.
	$(exec_verbose) VERSION='$(VERSION)' \
	CHANGELOG_NAME='$(CHANGELOG_NAME)' \
	CHANGELOG_EMAIL='$(CHANGELOG_EMAIL)' \
	CHANGELOG_PKG_REV='$(CHANGELOG_PKG_REV)' \
	CHANGELOG_COMMENT='$(CHANGELOG_COMMENT)' \
	CHANGELOG_ADDITIONAL_COMMENTS_FILE='$(CHANGELOG_ADDITIONAL_COMMENTS_FILE)' \
	release-build/deb-changelog-entry.sh \
	 $(DEPS_DIR)/rabbit/packaging/debs/Debian/debian/changelog

	$(verbose) VERSION='$(VERSION)' \
	CHANGELOG_NAME='$(CHANGELOG_NAME)' \
	CHANGELOG_EMAIL='$(CHANGELOG_EMAIL)' \
	CHANGELOG_PKG_REV='$(CHANGELOG_PKG_REV)' \
	CHANGELOG_COMMENT='$(CHANGELOG_COMMENT)' \
	release-build/rpm-changelog-entry.sh \
	 $(DEPS_DIR)/rabbit/packaging/RPMS/Fedora/rabbitmq-server.spec

# Build source archive.
	$(verbose) rm -rf $(SERVER_PACKAGES_DIR)
	$(verbose) mkdir -p $(SERVER_PACKAGES_DIR)
	$(verbose) $(MAKE) -C deps/rabbit source-dist PACKAGES_DIR=$(abspath $(SERVER_PACKAGES_DIR))
	$(verbose) rm -rf $(SERVER_PACKAGES_DIR)/rabbitmq-server-$(VERSION)

ifneq ($(UNIX_HOST),)
# This target is called "Unix packages" because it includes packages
# for Linux and a generic archive ready for any Unix system. However,
# it also includes the Windows installer! So by Unix packages, we mean
# "it's built on Unix".

release-server: release-unix-server-packages release-debian-repository

release-unix-server-packages: release-server-sources

UNIX_SERVER_SRCS += $(SIGNING_SRCS)
UNIX_SERVER_VARS += $(SIGNING_VARS)

# We do not clean the packages output directory in
# release-*-server-packages, because it's already done by
# release-server-sources, which is a dependency.

ifeq ($(UNIX_HOST),localhost)
release-unix-server-packages:
	$(exec_verbose) release-build/install-otp.sh "$(OTP_VERSION)"
	$(verbose) PATH="$$HOME/otp-$(OTP_VERSION)/bin:$$PATH" \
		$(MAKE) -C $(DEPS_DIR)/rabbit/packaging \
		SOURCE_DIST_FILE="$(abspath $(SOURCE_DIST_FILE))" \
		PACKAGES_DIR="$(abspath $(SERVER_PACKAGES_DIR))" \
		VERSION="$(VERSION)" \
		$(UNIX_SERVER_VARS) \
		NO_CLEAN=yes
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		--include '*.man.xml' \
		--exclude '*' \
		$(DEPS_DIR)/rabbit/packaging/generic-unix/rabbitmq-server-$(VERSION)/docs/ \
		$(SERVER_PACKAGES_DIR)/man/
else
release-unix-server-packages: REMOTE_RELEASE_TMPDIR = rabbitmq-server-$(VERSION)
release-unix-server-packages:
	$(exec_verbose) ssh $(SSH_OPTS) $(UNIX_HOST) \
		'rm -rf $(REMOTE_RELEASE_TMPDIR); \
		 mkdir -p $(REMOTE_RELEASE_TMPDIR)'
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		$(DEPS_DIR)/rabbit/packaging \
		$(SOURCE_DIST_FILE) \
		release-build/install-otp.sh \
		$(UNIX_SERVER_SRCS) \
		$(UNIX_HOST):$(REMOTE_RELEASE_TMPDIR)
	$(verbose) ssh $(SSH_OPTS) $(UNIX_HOST) \
		'chmod 755 $(REMOTE_RELEASE_TMPDIR)/install-otp.sh && \
		 $(REMOTE_RELEASE_TMPDIR)/install-otp.sh '$(OTP_VERSION)' && \
		 PATH="$$HOME/otp-$(OTP_VERSION)/bin:$$PATH" \
		 $(REMOTE_MAKE) -C "$(REMOTE_RELEASE_TMPDIR)/packaging" \
		 SOURCE_DIST_FILE="$$HOME/$(REMOTE_RELEASE_TMPDIR)/$(notdir $(SOURCE_DIST_FILE))" \
		 PACKAGES_DIR="PACKAGES" \
		 VERSION="$(VERSION)" \
		 $(UNIX_SERVER_VARS) \
		 NO_CLEAN=yes'
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		$(UNIX_HOST):$(REMOTE_RELEASE_TMPDIR)/packaging/PACKAGES/ \
		$(SERVER_PACKAGES_DIR)/
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		--include '*.man.xml' \
		--exclude '*' \
		$(UNIX_HOST):$(REMOTE_RELEASE_TMPDIR)/packaging/generic-unix/rabbitmq-server-$(VERSION)/docs/ \
		$(SERVER_PACKAGES_DIR)/man/
	$(verbose) ssh $(SSH_OPTS) $(UNIX_HOST) \
		'rm -rf $(REMOTE_RELEASE_TMPDIR)'
endif

release-debian-repository: release-unix-server-packages
	$(exec_verbose) rm -rf $(DEBIAN_REPO_DIR)
	$(verbose) mkdir -p $(DEBIAN_REPO_DIR)
	$(verbose) $(MAKE) -C $(DEPS_DIR)/rabbit/packaging/debs/apt-repository \
		PACKAGES_DIR=$(abspath $(SERVER_PACKAGES_DIR)) \
		REPO_DIR=$(abspath $(DEBIAN_REPO_DIR)) \
		GNUPG_PATH=$(abspath $(KEYSDIR)/keyring) \
		SIGNING_USER_EMAIL=$(SIGNING_USER_EMAIL)
endif

ifneq ($(MACOSX_HOST),)
release-server: release-macosx-server-packages

release-macosx-server-packages: release-server-sources

ifeq ($(MACOSX_HOST),localhost)
release-macosx-server-packages:
	$(exec_verbose) release-build/install-otp.sh "$(STANDALONE_OTP_VERSION)"
	$(verbose) PATH="$$HOME/otp-$(STANDALONE_OTP_VERSION)/bin:$$PATH" \
		$(MAKE) -C $(DEPS_DIR)/rabbit/packaging \
		package-standalone-macosx \
		SOURCE_DIST_FILE="$(abspath $(SOURCE_DIST_FILE))" \
		PACKAGES_DIR="$(abspath $(SERVER_PACKAGES_DIR))" \
		VERSION="$(VERSION)"
else
release-macosx-server-packages: REMOTE_RELEASE_TMPDIR = rabbitmq-server-$(VERSION)
release-macosx-server-packages:
	$(exec_verbose) ssh $(SSH_OPTS) $(MACOSX_HOST) \
		'rm -rf $(REMOTE_RELEASE_TMPDIR); \
		 mkdir -p $(REMOTE_RELEASE_TMPDIR)'
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		$(DEPS_DIR)/rabbit/packaging \
		$(SOURCE_DIST_FILE) \
		release-build/install-otp.sh \
		$(MACOSX_HOST):$(REMOTE_RELEASE_TMPDIR)
	$(verbose) ssh $(SSH_OPTS) $(MACOSX_HOST) \
		'chmod 755 $(REMOTE_RELEASE_TMPDIR)/install-otp.sh && \
		 $(REMOTE_RELEASE_TMPDIR)/install-otp.sh '$(STANDALONE_OTP_VERSION)' && \
		 PATH="$$HOME/otp-$(STANDALONE_OTP_VERSION)/bin:$$PATH" \
		 $(REMOTE_MAKE) -C "$(REMOTE_RELEASE_TMPDIR)/packaging" \
		 package-standalone-macosx \
		 SOURCE_DIST_FILE="$$HOME/$(REMOTE_RELEASE_TMPDIR)/$(notdir $(SOURCE_DIST_FILE))" \
		 PACKAGES_DIR="PACKAGES" \
		 VERSION="$(VERSION)" \
		 NO_CLEAN=yes'
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		$(MACOSX_HOST):$(REMOTE_RELEASE_TMPDIR)/packaging/PACKAGES/ \
		$(SERVER_PACKAGES_DIR)/
	$(verbose) ssh $(SSH_OPTS) $(MACOSX_HOST) \
		'rm -rf $(REMOTE_RELEASE_TMPDIR)'
endif
endif

ifneq ($(UNIX_HOST),)
release-clients: release-java-client

JAVA_CLIENT_SRCS = $(DEPS_DIR)/rabbitmq_java_client \
		   $(DEPS_DIR)/rabbitmq_codegen \
		   $(CLIENTS_BUILD_DOC_DIR)/build-java-client.txt

release-java-client: $(DEPS_DIR)/rabbitmq_java_client release-clients-build-doc

ifeq ($(UNIX_HOST),localhost)
release-java-client:
	$(exec_verbose) $(MAKE) -C "$(DEPS_DIR)/rabbitmq_java_client" \
		dist \
		VERSION="$(VERSION)" \
		BUILD_DOC="$(abspath $(CLIENTS_BUILD_DOC_DIR)/build-java-client.txt)"
	$(verbose) rm -rf $(JAVA_CLIENT_PACKAGES_DIR)
	$(verbose) mkdir -p $(JAVA_CLIENT_PACKAGES_DIR)
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		$(DEPS_DIR)/rabbitmq_java_client/build/*.tar.gz \
		$(DEPS_DIR)/rabbitmq_java_client/build/*.zip \
		$(DEPS_DIR)/rabbitmq_java_client/build/bundle \
		$(JAVA_CLIENT_PACKAGES_DIR)
	$(verbose) cd $(JAVA_CLIENT_PACKAGES_DIR) && \
		unzip -q rabbitmq-java-client-javadoc-$(VERSION).zip
else
release-java-client: REMOTE_RELEASE_TMPDIR = rabbitmq-java-client-$(VERSION)
release-java-client:
	$(exec_verbose) ssh $(SSH_OPTS) $(UNIX_HOST) \
		'rm -rf $(REMOTE_RELEASE_TMPDIR); \
		 mkdir -p $(REMOTE_RELEASE_TMPDIR)'
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		$(JAVA_CLIENT_SRCS) \
		$(UNIX_HOST):$(REMOTE_RELEASE_TMPDIR)
	$(verbose) ssh $(SSH_OPTS) $(UNIX_HOST) \
		'$(REMOTE_MAKE) -C "$(REMOTE_RELEASE_TMPDIR)/rabbitmq_java_client" \
		 dist \
		 VERSION="$(VERSION)" \
		 BUILD_DOC="$$HOME/$(REMOTE_RELEASE_TMPDIR)/build-java-client.txt"'
	$(verbose) rm -rf $(JAVA_CLIENT_PACKAGES_DIR)
	$(verbose) mkdir -p $(JAVA_CLIENT_PACKAGES_DIR)
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		--include '*.tar.gz' \
		--include '*.zip' \
		--include 'bundle' --include 'bundle/*' \
		--exclude '*' \
		$(UNIX_HOST):$(REMOTE_RELEASE_TMPDIR)/rabbitmq_java_client/build/ \
		$(JAVA_CLIENT_PACKAGES_DIR)/
	$(verbose) ssh $(SSH_OPTS) $(UNIX_HOST) \
		'rm -rf $(REMOTE_RELEASE_TMPDIR)'
	$(verbose) cd $(JAVA_CLIENT_PACKAGES_DIR) && \
		unzip -q rabbitmq-java-client-javadoc-$(VERSION).zip
endif
endif

ifneq ($(WINDOWS_HOST),)
release-clients: release-dotnet-client

DOTNET_CLIENT_SRCS = $(DEPS_DIR)/rabbitmq_dotnet_client \
		     $(CLIENTS_BUILD_DOC_DIR)/build-dotnet-client.txt

DOTNET_CLIENT_VARS = RABBIT_VSN=$(VERSION) \
		     SKIP_MSIVAL2=1

ifneq ($(KEYSDIR),)
ifeq ($(WINDOWS_HOST),localhost)
DOTNET_CLIENT_VARS += KEYFILE=$(abspath $(KEYSDIR)/dotnet/rabbit.snk)
else
DOTNET_CLIENT_SRCS += $(KEYSDIR)/dotnet/rabbit.snk
DOTNET_CLIENT_VARS += KEYFILE="$$HOME/$(REMOTE_RELEASE_TMPDIR)/rabbit.snk"
endif
endif

release-dotnet-client: $(DEPS_DIR)/rabbitmq_dotnet_client release-clients-build-doc

ifeq ($(WINDOWS_HOST),localhost)
release-dotnet-client:
	$(exec_verbose) cd $(DEPS_DIR)/rabbitmq_dotnet_client && \
		$(DOTNET_CLIENT_VARS) \
		BUILD_DOC=$(abspath $(CLIENTS_BUILD_DOC_DIR)/build-dotnet-client.txt) \
		./dist.sh
	$(verbose) $(MAKE) -C "$(DEPS_DIR)/rabbitmq_dotnet_client" \
		doc dist \
		RABBIT_VSN="$(VERSION)"
	$(verbose) rm -rf $(DOTNET_CLIENT_PACKAGES_DIR)
	$(verbose) mkdir -p $(DOTNET_CLIENT_PACKAGES_DIR)
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		$(DEPS_DIR)/rabbitmq_dotnet_client/releases/* \
		$(DOTNET_CLIENT_PACKAGES_DIR)
else
release-dotnet-client: REMOTE_RELEASE_TMPDIR = rabbitmq-dotnet-client-$(VERSION)
release-dotnet-client:
	$(exec_verbose) ssh $(SSH_OPTS) $(WINDOWS_HOST) \
		'rm -rf $(REMOTE_RELEASE_TMPDIR); \
		 mkdir -p $(REMOTE_RELEASE_TMPDIR)'
	$(verbose) rsync $(RSYNC_FLAGS) \
		$(DOTNET_CLIENT_SRCS) \
		$(WINDOWS_HOST):$(REMOTE_RELEASE_TMPDIR)
	$(verbose) ssh $(SSH_OPTS) $(WINDOWS_HOST) \
		'$(DOTNET_CLIENT_VARS) \
		 BUILD_DOC=$$HOME/$(REMOTE_RELEASE_TMPDIR)/build-dotnet-client.txt \
		 $(REMOTE_RELEASE_TMPDIR)/rabbitmq_dotnet_client/dist.sh && \
		 $(REMOTE_MAKE) -C "$(REMOTE_RELEASE_TMPDIR)/rabbitmq_dotnet_client" \
		 doc dist \
		 RABBIT_VSN="$(VERSION)"'
	$(verbose) rm -rf $(DOTNET_CLIENT_PACKAGES_DIR)
	$(verbose) mkdir -p $(DOTNET_CLIENT_PACKAGES_DIR)
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		$(WINDOWS_HOST):$(REMOTE_RELEASE_TMPDIR)/rabbitmq_dotnet_client/release/ \
		$(DOTNET_CLIENT_PACKAGES_DIR)/
	$(verbose) ssh $(SSH_OPTS) $(WINDOWS_HOST) \
		'rm -rf $(REMOTE_RELEASE_TMPDIR)'
endif
endif

release-clients: release-erlang-client

release-erlang-client: release-erlang-client-sources
	@:

release-erlang-client-sources: release-clients-build-doc
	$(exec_verbose) rm -rf $(ERLANG_CLIENT_PACKAGES_DIR)
	$(verbose) mkdir -p $(ERLANG_CLIENT_PACKAGES_DIR)
	$(verbose) $(MAKE) -C "$(DEPS_DIR)/amqp_client" source-dist \
		BUILD_DOC="$(abspath $(CLIENTS_BUILD_DOC_DIR)/build-erlang-client.txt)" \
		PACKAGES_DIR=$(abspath $(ERLANG_CLIENT_PACKAGES_DIR))
	$(verbose) rm -rf $(ERLANG_CLIENT_PACKAGES_DIR)/amqp_client-$(VERSION)-src

ifneq ($(UNIX_HOST),)
release-erlang-client: release-erlang-client-package

ifeq ($(UNIX_HOST),localhost)
release-erlang-client-package: release-erlang-client-sources
	$(exec_verbose) $(MAKE) -C "$(DEPS_DIR)/amqp_client" \
		dist docs \
		VERSION="$(VERSION)" \
		PACKAGES_DIR=$(abspath $(ERLANG_CLIENT_PACKAGES_DIR))
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		$(DEPS_DIR)/amqp_client/plugins/ \
		$(ERLANG_CLIENT_PACKAGES_DIR)/
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		$(DEPS_DIR)/amqp_client/doc \
		$(ERLANG_CLIENT_PACKAGES_DIR)
else
release-erlang-client-package: REMOTE_RELEASE_TMPDIR = rabbitmq-erlang-client-$(VERSION)
release-erlang-client-package: release-erlang-client-sources
	$(exec_verbose) ssh $(SSH_OPTS) $(UNIX_HOST) \
		'rm -rf $(REMOTE_RELEASE_TMPDIR); \
		 mkdir -p $(REMOTE_RELEASE_TMPDIR)'
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		$(ERLANG_CLIENT_PACKAGES_DIR)/amqp_client-$(VERSION)-src.tar.xz \
		$(UNIX_HOST):$(REMOTE_RELEASE_TMPDIR)
	$(verbose) ssh $(SSH_OPTS) $(UNIX_HOST) \
		'cd $(REMOTE_RELEASE_TMPDIR) && \
		 xzcat amqp_client-$(VERSION)-src.tar.xz | tar -xf - && \
		 $(REMOTE_MAKE) -C "amqp_client-$(VERSION)-src" dist docs \
		  VERSION=$(VERSION) \
		  V=$(V)'
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		$(UNIX_HOST):$(REMOTE_RELEASE_TMPDIR)/amqp_client-$(VERSION)-src/plugins/ \
		$(ERLANG_CLIENT_PACKAGES_DIR)/
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		$(UNIX_HOST):$(REMOTE_RELEASE_TMPDIR)/amqp_client-$(VERSION)-src/doc \
		$(ERLANG_CLIENT_PACKAGES_DIR)
	$(verbose) ssh $(SSH_OPTS) $(UNIX_HOST) \
		'rm -rf $(REMOTE_RELEASE_TMPDIR)'
endif
endif

release-clients-build-doc: $(DEPS_DIR)/rabbitmq_website
	$(exec_verbose) rm -rf $(CLIENTS_BUILD_DOC_DIR)
	$(verbose) mkdir -p $(CLIENTS_BUILD_DOC_DIR)
	$(verbose) cd $(DEPS_DIR)/rabbitmq_website; \
		python driver.py www & \
		sleep 1; \
		trap "kill $$!" EXIT; \
		set -e; for file in build-java-client.html build-dotnet-client.html build-erlang-client.html; do \
			elinks -dump -no-references -no-numbering \
			 http://localhost:8191/$$file > \
			 $(abspath $(CLIENTS_BUILD_DOC_DIR))/$${file%.html}.txt; \
		done

# Signing artifacts.

.PHONY: sign-artifacts verify-signatures

sign-artifacts:
	$(exec_verbopse) python util/nopassphrase.py \
		rpm --addsign \
		 --define '_signature gpg' \
		 --define '_gpg_path $(KEYSDIR)/keyring/.gnupg' \
		 --define '_gpg_name $(SIGNING_USER_ID)' \
		 $(SERVER_PACKAGES_DIR)/*.rpm
	$(verbose) for p in \
		$(SERVER_PACKAGES_DIR)/* \
		$(JAVA_CLIENT_PACKAGES_DIR)/* \
		$(DOTNET_CLIENT_PACKAGES_DIR)/* \
		$(ERLANG_CLIENT_PACKAGES_DIR)/* \
	; do \
		[ -f $$p ] && \
		HOME='$(abspath $(KEYSDIR)/keyring)' gpg \
		 $(if $(SIGNING_KEY),--default-key $(SIGNING_KEY)) \
		 -abs -o $$p.asc $$p; \
	done

verify-signatures:
	$(exec_verbose) for file in `find $(PACKAGES_DIR) -type f -name "*.asc"`; do \
		echo "Checking $$file"; \
		if ! HOME='$(abspath $(KEYSDIR)/keyring)' gpg --verify $$file $${file%.asc}; then \
			bad_signature=1; \
		fi; \
	done; \
	[ -z "$$bad_signature" ]

# Deployment.

DEPLOY_HOST ?= localhost
DEPLOY_PATH ?= /tmp/rabbitmq/extras/releases

DEPLOYMENT_SUBDIRS = $(SERVER_PACKAGES_DIR) \
		     $(JAVA_CLIENT_PACKAGES_DIR) \
		     $(DOTNET_CLIENT_PACKAGES_DIR) \
		     $(ERLANG_CLIENT_PACKAGES_DIR) \
		     $(DEBIAN_REPO_DIR)

DEPLOY_RSYNC_FLAGS = -rpl --delete-after $(RSYNC_V)

define make_target_start

	$(verbose)
endef

.PHONY: fixup-permissions-for-deploy deploy deploy-maven

fixup-permissions-for-deploy:
	$(exec_verbose) chmod -R g+w $(PACKAGES_DIR)
	$(verbose) chmod g+s `find $(PACKAGES_DIR) -type d`

deploy: verify-signatures fixup-permissions-for-deploy

ifeq ($(DEPLOY_HOST),localhost)
deploy:
	$(exec_verbose) mkdir -p $(patsubst $(PACKAGES_DIR)/%,$(DEPLOY_PATH)/%,$(DEPLOYMENT_SUBDIRS))
	$(foreach DIR,$(DEPLOYMENT_SUBDIRS),\
		$(make_target_start) $(RSYNC) $(DEPLOY_RSYNC_FLAGS) \
			$(DIR)/ \
			$(DEPLOY_PATH)/$(patsubst $(PACKAGES_DIR)/%,%,$(DIR))/ \
	)
	$(verbose) cd $(DEPLOY_PATH)/rabbitmq-java-client; \
		 rm -f current-javadoc; \
		 ln -s \
		  `cd $(abspath $(JAVA_CLIENT_PACKAGES_DIR)/..) && \
		   ls -td */rabbitmq-java-client-javadoc-*/ | head -1` current-javadoc
	$(verbose) cd $(DEPLOY_PATH)/rabbitmq-server; \
		 rm -f current; \
		 ln -s v$(VERSION) current
else
deploy:
	$(exec_verbose) ssh $(SSH_OPTS) $(DEPLOY_HOST) \
		'mkdir -p $(patsubst $(PACKAGES_DIR)/%,$(DEPLOY_PATH)/%,$(DEPLOYMENT_SUBDIRS))'
	$(foreach DIR,$(DEPLOYMENT_SUBDIRS),\
		$(make_target_start) $(RSYNC) $(DEPLOY_RSYNC_FLAGS) \
			$(DIR)/ \
			$(DEPLOY_HOST):$(DEPLOY_PATH)/$(patsubst $(PACKAGES_DIR)/%,%,$(DIR))/ \
	)
	$(verbose) ssh $(SSH_OPTS) $(DEPLOY_HOST) \
		"(cd $(DEPLOY_PATH)/rabbitmq-java-client; \
		 rm -f current-javadoc; \
		 ln -s \
		  `cd $(abspath $(JAVA_CLIENT_PACKAGES_DIR)/..) && \
		   ls -td */rabbitmq-java-client-javadoc-*/ | head -1` current-javadoc)"
	$(verbose) ssh $(SSH_OPTS) $(DEPLOY_HOST) \
		'(cd $(DEPLOY_PATH)/rabbitmq-server; \
		 rm -f current; \
		 ln -s v$(VERSION) current)'
endif

deploy-maven: $(DEPS_DIR)/rabbitmq_java_client verify-signatures fixup-permissions-for-deploy
	$(exec_verbose) \
	NEXUS_USERNAME=$$(cat $(KEYSDIR)/nexus/username); \
	NEXUS_PASSWORD=$$(cat $(KEYSDIR)/nexus/password); \
	VERSION=$(VERSION) \
		$(SIGNING_VARS) \
		CREDS="$$NEXUS_USERNAME:$$NEXUS_PASSWORD" \
		$(DEPS_DIR)/rabbitmq_java_client/nexus-upload.sh \
		$(JAVA_CLIENT_PACKAGES_DIR)/bundle/amqp-client-$(VERSION).pom \
		$(JAVA_CLIENT_PACKAGES_DIR)/bundle/amqp-client-$(VERSION).jar \
		$(JAVA_CLIENT_PACKAGES_DIR)/bundle/amqp-client-$(VERSION)-javadoc.jar \
		$(JAVA_CLIENT_PACKAGES_DIR)/bundle/amqp-client-$(VERSION)-sources.jar
