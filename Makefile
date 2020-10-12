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

branch: $(abspath .)+branch $(READY_DEPS:%=$(DEPS_DIR)/%+branch)
	@:

%+branch:
	@cd $* && pwd && git branch && echo

push: $(abspath .)+push $(READY_DEPS:%=$(DEPS_DIR)/%+push)
	@:

%+push:
	$(exec_verbose) cd $*; \
	git push && \
	echo

tag: $(abspath .)+tag $(READY_DEPS:%=$(DEPS_DIR)/%+tag)
	@:

%+tag:
	$(exec_verbose) test "$(TAG)" || (printf "\nERROR: TAG must be set\n\n" 1>&2; false)
	$(verbose) cd $*; \
	git tag $(TAG) && \
	echo

update-copyright: $(abspath .)+update-copyright $(READY_DEPS:%=$(DEPS_DIR)/%+update-copyright)
	@:

UPDATE_COPYRIGHT_SCRIPT = $(CURDIR)/update-copyright.sh

# Set DO_COMMIT=yes on the make(1) command line to tell the script to
# commit the result.
%+update-copyright:
	$(gen_verbose) cd $*; \
	(git diff --quiet && \
	 git diff --quiet --cached && \
	 $(UPDATE_COPYRIGHT_SCRIPT)) || \
	(echo "$(notdir $*): Please commit your local changes first" 1>&2; \
	 echo; \
	 exit 1)

clean:: clean-subrepos clean-3rd-party-repos

clean-subrepos: $(READY_DEPS:%=$(DEPS_DIR)/%+clean)
	@:

THIRD_PARTY_DEPS_DIRS = $(filter-out $(patsubst %,$(DEPS_DIR)/%,$(READY_DEPS)),$(wildcard $(DEPS_DIR)/*))

ifeq ($(DEPS_DIR),$(CURDIR)/deps)
clean-3rd-party-repos:
	$(verbose) rm -rf $(THIRD_PARTY_DEPS_DIRS)
else
clean-3rd-party-repos:
	@:
endif

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
ERLANG_CLIENT_PACKAGES_DIR ?= $(PACKAGES_DIR)/rabbitmq-erlang-client/v$(VERSION)
CLIENTS_BUILD_DOC_DIR ?= $(PACKAGES_DIR)/clients-build-doc/v$(VERSION)
DEBIAN_REPO_DIR ?= $(PACKAGES_DIR)/debian

UNIX_HOST ?=
MACOSX_HOST ?=

# Default to the nightly signing key.
SIGNING_KEY ?= 0xD441A9DDBA058EF7

ifneq ($(KEYSDIR),)
ifeq ($(UNIX_HOST),)
SIGNING_VARS += GNUPG_PATH=$(abspath $(KEYSDIR)/keyring)
else ifeq ($(UNIX_HOST),localhost)
SIGNING_VARS += GNUPG_PATH=$(abspath $(KEYSDIR)/keyring)
else
SIGNING_SRCS += $(KEYSDIR)/keyring
SIGNING_VARS += GNUPG_PATH="$$HOME/$(REMOTE_RELEASE_TMPDIR)/keyring"
endif

SIGNING_VARS += SIGNING_KEY="$(SIGNING_KEY)"
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
	$(DEPS_DIR)/rabbitmq_server_release/packaging/debs/Debian/changelog_comments/additional_changelog_comments_$(VERSION)

OTP_VERSION ?= 19.2
STANDALONE_OTP_VERSION ?= 19.2.3
ELIXIR_VERSION ?= 1.4.5

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

release-server-sources: $(DEPS_DIR)/rabbitmq_server_release
# Prepare changelog entries.
	$(exec_verbose) VERSION='$(VERSION)' \
	CHANGELOG_NAME='$(CHANGELOG_NAME)' \
	CHANGELOG_EMAIL='$(CHANGELOG_EMAIL)' \
	CHANGELOG_PKG_REV='$(CHANGELOG_PKG_REV)' \
	CHANGELOG_COMMENT='$(CHANGELOG_COMMENT)' \
	CHANGELOG_ADDITIONAL_COMMENTS_FILE='$(CHANGELOG_ADDITIONAL_COMMENTS_FILE)' \
	release-build/deb-changelog-entry.sh \
	 $(DEPS_DIR)/rabbitmq_server_release/packaging/debs/Debian/debian/changelog

	$(verbose) VERSION='$(VERSION)' \
	CHANGELOG_NAME='$(CHANGELOG_NAME)' \
	CHANGELOG_EMAIL='$(CHANGELOG_EMAIL)' \
	CHANGELOG_PKG_REV='$(CHANGELOG_PKG_REV)' \
	CHANGELOG_COMMENT='$(CHANGELOG_COMMENT)' \
	release-build/rpm-changelog-entry.sh \
	 $(DEPS_DIR)/rabbitmq_server_release/packaging/RPMS/Fedora/rabbitmq-server.spec

# Build source archive.
	$(verbose) rm -rf $(SERVER_PACKAGES_DIR)
	$(verbose) mkdir -p $(SERVER_PACKAGES_DIR)
	$(verbose) $(MAKE) -C deps/rabbitmq_server_release source-dist \
	 PACKAGES_DIR=$(abspath $(SERVER_PACKAGES_DIR)) \
	 PROJECT_VERSION=$(VERSION)
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
	$(exec_verbose) PATH="$$HOME/otp-$(OTP_VERSION)/bin:$$PATH" \
		release-build/install-elixir.sh "$(ELIXIR_VERSION)"
	$(verbose) PATH="$$HOME/otp-$(OTP_VERSION)/bin:$$HOME/elixir-$(ELIXIR_VERSION)/bin:$$PATH" \
		$(MAKE) -C $(DEPS_DIR)/rabbitmq_server_release/packaging \
		SOURCE_DIST_FILE="$(abspath $(SOURCE_DIST_FILE))" \
		PACKAGES_DIR="$(abspath $(SERVER_PACKAGES_DIR))" \
		VERSION="$(VERSION)" \
		$(UNIX_SERVER_VARS) \
		NO_CLEAN=yes
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		--include '*.html' \
		--exclude '*' \
		$(DEPS_DIR)/rabbitmq_server_release/packaging/generic-unix/rabbitmq-server-$(VERSION)/deps/rabbit/docs/ \
		$(SERVER_PACKAGES_DIR)/man/
else
release-unix-server-packages: REMOTE_RELEASE_TMPDIR = rabbitmq-server-$(VERSION)
release-unix-server-packages:
	$(exec_verbose) ssh $(SSH_OPTS) $(UNIX_HOST) \
		'rm -rf $(REMOTE_RELEASE_TMPDIR); \
		 mkdir -p $(REMOTE_RELEASE_TMPDIR)'
	$(verbose) $(RSYNC) $(RSYNC_FLAGS) \
		$(DEPS_DIR)/rabbitmq_server_release/packaging \
		$(SOURCE_DIST_FILE) \
		release-build/install-*.sh \
		$(UNIX_SERVER_SRCS) \
		$(UNIX_HOST):$(REMOTE_RELEASE_TMPDIR)
	$(verbose) ssh $(SSH_OPTS) $(UNIX_HOST) \
		'chmod 755 $(REMOTE_RELEASE_TMPDIR)/install-*.sh && \
		 $(REMOTE_RELEASE_TMPDIR)/install-otp.sh '$(OTP_VERSION)' && \
		 PATH="$$HOME/otp-$(OTP_VERSION)/bin:$$PATH" \
		 $(REMOTE_RELEASE_TMPDIR)/install-elixir.sh '$(ELIXIR_VERSION)' && \
		 PATH="$$HOME/otp-$(OTP_VERSION)/bin:$$PATH:$$HOME/elixir-$(ELIXIR_VERSION)/bin" \
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
		--include '*.html' \
		--exclude '*' \
		$(UNIX_HOST):$(REMOTE_RELEASE_TMPDIR)/packaging/generic-unix/rabbitmq-server-$(VERSION)/deps/rabbit/docs/ \
		$(SERVER_PACKAGES_DIR)/man/
	$(verbose) ssh $(SSH_OPTS) $(UNIX_HOST) \
		'rm -rf $(REMOTE_RELEASE_TMPDIR)'
endif

release-debian-repository: release-unix-server-packages
	$(exec_verbose) rm -rf $(DEBIAN_REPO_DIR)
	$(verbose) mkdir -p $(DEBIAN_REPO_DIR)
	$(verbose) $(MAKE) -C $(DEPS_DIR)/rabbitmq_server_release/packaging/debs/apt-repository \
		PACKAGES_DIR=$(abspath $(SERVER_PACKAGES_DIR)) \
		REPO_DIR=$(abspath $(DEBIAN_REPO_DIR)) \
		GNUPG_PATH=$(abspath $(KEYSDIR)/keyring) \
		SIGNING_KEY=$(SIGNING_KEY)
endif

ifneq ($(MACOSX_HOST),)
release-server: release-macosx-server-packages

release-macosx-server-packages: release-server-sources

ifeq ($(MACOSX_HOST),localhost)
release-macosx-server-packages:
	$(exec_verbose) release-build/install-otp.sh "$(STANDALONE_OTP_VERSION)"
	$(exec_verbose) PATH="$$HOME/otp-$(STANDALONE_OTP_VERSION)/bin:$$PATH" \
		release-build/install-elixir.sh "$(ELIXIR_VERSION)"
	$(verbose) PATH="$$HOME/otp-$(STANDALONE_OTP_VERSION)/bin:$$HOME/elixir-$(ELIXIR_VERSION)/bin:$$PATH" \
		$(MAKE) -C $(DEPS_DIR)/rabbitmq_server_release/packaging \
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
		$(DEPS_DIR)/rabbitmq_server_release/packaging \
		$(SOURCE_DIST_FILE) \
		release-build/install-*.sh \
		$(MACOSX_HOST):$(REMOTE_RELEASE_TMPDIR)
	$(verbose) ssh $(SSH_OPTS) $(MACOSX_HOST) \
		'chmod 755 $(REMOTE_RELEASE_TMPDIR)/install-*.sh && \
		 $(REMOTE_RELEASE_TMPDIR)/install-otp.sh '$(STANDALONE_OTP_VERSION)' && \
		 PATH="$$HOME/otp-$(STANDALONE_OTP_VERSION)/bin:$$PATH" \
		 $(REMOTE_RELEASE_TMPDIR)/install-elixir.sh '$(ELIXIR_VERSION)' && \
		 PATH="$$HOME/otp-$(STANDALONE_OTP_VERSION)/bin:$$HOME/elixir-$(ELIXIR_VERSION)/bin:$$PATH" \
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

release-clients: release-erlang-client

release-erlang-client: release-erlang-client-sources
	@:

release-erlang-client-sources: release-clients-build-doc
	$(exec_verbose) rm -rf $(ERLANG_CLIENT_PACKAGES_DIR)
	$(verbose) mkdir -p $(ERLANG_CLIENT_PACKAGES_DIR)
	$(verbose) $(MAKE) -C "$(DEPS_DIR)/amqp_client" source-dist \
		BUILD_DOC="$(abspath $(CLIENTS_BUILD_DOC_DIR)/build-erlang-client.txt)" \
		PACKAGES_DIR=$(abspath $(ERLANG_CLIENT_PACKAGES_DIR)) \
		PROJECT_VERSION=$(VERSION)
	$(verbose) rm -rf $(ERLANG_CLIENT_PACKAGES_DIR)/amqp_client-$(VERSION)-src

ifneq ($(UNIX_HOST),)
release-erlang-client: release-erlang-client-package

ifeq ($(UNIX_HOST),localhost)
release-erlang-client-package: release-erlang-client-sources
	$(exec_verbose) release-build/install-otp.sh "$(OTP_VERSION)"
	$(verbose) PATH="$$HOME/otp-$(OTP_VERSION)/bin:$$PATH" \
		$(MAKE) -C "$(DEPS_DIR)/amqp_client" \
		dist docs \
		PROJECT_VERSION="$(VERSION)" \
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
		release-build/install-otp.sh \
		$(UNIX_HOST):$(REMOTE_RELEASE_TMPDIR)
	$(verbose) ssh $(SSH_OPTS) $(UNIX_HOST) \
		'chmod 755 $(REMOTE_RELEASE_TMPDIR)/install-otp.sh && \
		 $(REMOTE_RELEASE_TMPDIR)/install-otp.sh '$(OTP_VERSION)' && \
		 cd $(REMOTE_RELEASE_TMPDIR) && \
		 xzcat amqp_client-$(VERSION)-src.tar.xz | tar -xf - && \
		 PATH="$$HOME/otp-$(OTP_VERSION)/bin:$$PATH" \
		 $(REMOTE_MAKE) -C "amqp_client-$(VERSION)-src" dist docs \
		  PROJECT_VERSION=$(VERSION) \
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
		set -e; for file in build-erlang-client.html; do \
			elinks -dump -no-references -no-numbering \
			 http://localhost:8191/$$file > \
			 $(abspath $(CLIENTS_BUILD_DOC_DIR))/$${file%.html}.txt; \
		done

# Signing artifacts.

.PHONY: sign-artifacts verify-signatures

sign-artifacts:
	$(verbose) for p in \
		$(SERVER_PACKAGES_DIR)/* \
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
		     $(ERLANG_CLIENT_PACKAGES_DIR) \
		     $(DEBIAN_REPO_DIR)

DEPLOYMENT_SUBDIRS := $(foreach DIR,$(DEPLOYMENT_SUBDIRS),$(if $(wildcard $(DIR)),$(DIR),))

DEPLOY_RSYNC_FLAGS = -rpl --delete-after $(RSYNC_V)

define make_target_start

	$(verbose)
endef

.PHONY: fixup-permissions-for-deploy deploy

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
		'(cd $(DEPLOY_PATH)/rabbitmq-server; \
		 rm -f current; \
		 ln -s v$(VERSION) current)'
endif

# https://hub.docker.com/r/pivotalrabbitmq/rabbitmq-server-buildenv/tags
DOCKER_IMAGE ?= pivotalrabbitmq/rabbitmq-server-buildenv:linux-erlang-22.3-elixir-latest
workspace:
	docker pull $(DOCKER_IMAGE) \
	&& docker run \
	  --interactive --tty --rm \
	  --volume $(CURDIR):/workspace \
	  --workdir /workspace \
	  --publish 15672:15672 \
	  --publish 15692:15692 \
	  $(DOCKER_IMAGE) \
	  bash
