PROJECT = rabbitmq_public_umbrella

DEPS = $(RABBITMQ_COMPONENTS)

.DEFAULT_GOAL = up

NO_AUTOPATCH = $(DEPS)
DEP_PLUGINS = rabbit_common/mk/rabbitmq-run.mk

# FIXME: Use erlang.mk patched for RabbitMQ, while waiting for PRs to be
# reviewed and merged.

ERLANG_MK_REPO = https://github.com/rabbitmq/erlang.mk.git
ERLANG_MK_COMMIT = rabbitmq-tmp

include rabbitmq-components.mk
include erlang.mk

READY_DEPS = $(foreach DEP,$(DEPS), \
	     $(if $(wildcard $(DEPS_DIR)/$(DEP)),$(DEP),))

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
	git push && \
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
PACKAGES_DIR ?= packages/$(VERSION)

UNIX_HOST ?=
MACOSX_HOST ?=
WINDOWS_HOST ?=

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

SOURCE_DIST_FILE = $(PACKAGES_DIR)/rabbitmq-server-$(VERSION).tar.xz

REMOTE_MAKE ?= $(MAKE)

.PHONY: release release-source-dist release-server release-clients

release: release-server
	@:

release-server: release-server-sources

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
	$(verbose) $(MAKE) -C deps/rabbit source-dist PACKAGES_DIR=$(abspath $(PACKAGES_DIR))
	$(verbose) rm -rf $(PACKAGES_DIR)/rabbitmq-server-$(VERSION)

ifneq ($(UNIX_HOST),)
# This target is called "Unix packages" because it includes packages
# for Linux and a generic archive ready for any Unix system. However,
# it also includes the Windows installer! So by Unix packages, we mean
# "it's built on Unix".

release-server: release-unix-server-packages

release-unix-server-packages: release-server-sources

ifeq ($(UNIX_HOST),localhost)
release-unix-server-packages:
	$(exec_verbose) release-build/install-otp.sh "$(OTP_VERSION)"
	$(verbose) PATH="$$HOME/otp-$(OTP_VERSION)/bin:$$PATH" \
		$(MAKE) -C $(DEPS_DIR)/rabbit/packaging \
		SOURCE_DIST_FILE="$(abspath $(SOURCE_DIST_FILE))" \
		PACKAGES_DIR="$(abspath $(PACKAGES_DIR))" \
		VERSION="$(VERSION)"
else
release-unix-server-packages: REMOTE_RELEASE_TMPDIR=rabbitmq-server-$(VERSION)
release-unix-server-packages:
	$(exec_verbose) ssh $(SSH_OPTS) $(UNIX_HOST) \
		'rm -rf $(REMOTE_RELEASE_TMPDIR)'
	$(verbose) scp -rp -q $(DEPS_DIR)/rabbit/packaging \
		$(UNIX_HOST):$(REMOTE_RELEASE_TMPDIR)
	$(verbose) scp -p -q $(SOURCE_DIST_FILE) release-build/install-otp.sh \
		$(UNIX_HOST):$(REMOTE_RELEASE_TMPDIR)
	$(verbose) ssh $(SSH_OPTS) $(UNIX_HOST) \
		'chmod 755 $(REMOTE_RELEASE_TMPDIR)/install-otp.sh && \
		 $(REMOTE_RELEASE_TMPDIR)/install-otp.sh '$(OTP_VERSION)' && \
		 PATH="$$HOME/otp-$(OTP_VERSION)/bin:$$PATH" \
		 $(REMOTE_MAKE) -C "$(REMOTE_RELEASE_TMPDIR)" \
		 SOURCE_DIST_FILE="$(notdir $(SOURCE_DIST_FILE))" \
		 PACKAGES_DIR="PACKAGES" \
		 VERSION="$(VERSION)"'
	$(verbose) scp -p $(UNIX_HOST):$(REMOTE_RELEASE_TMPDIR)/PACKAGES/'*' \
		$(PACKAGES_DIR)
	$(verbose) ssh $(SSH_OPTS) $(UNIX_HOST) \
		'rm -rf $(REMOTE_RELEASE_TMPDIR)'
endif
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
		PACKAGES_DIR="$(abspath $(PACKAGES_DIR))" \
		VERSION="$(VERSION)"
else
release-macosx-server-packages: REMOTE_RELEASE_TMPDIR=rabbitmq-server-$(VERSION)
release-macosx-server-packages:
	$(exec_verbose) ssh $(SSH_OPTS) $(MACOSX_HOST) \
		'rm -rf $(REMOTE_RELEASE_TMPDIR)'
	$(verbose) scp -rp -q $(DEPS_DIR)/rabbit/packaging \
		$(MACOSX_HOST):$(REMOTE_RELEASE_TMPDIR)
	$(verbose) scp -p -q $(SOURCE_DIST_FILE) release-build/install-otp.sh \
		$(MACOSX_HOST):$(REMOTE_RELEASE_TMPDIR)
	$(verbose) ssh $(SSH_OPTS) $(MACOSX_HOST) \
		'chmod 755 $(REMOTE_RELEASE_TMPDIR)/install-otp.sh && \
		 $(REMOTE_RELEASE_TMPDIR)/install-otp.sh '$(STANDALONE_OTP_VERSION)' && \
		 PATH="$$HOME/otp-$(STANDALONE_OTP_VERSION)/bin:$$PATH" \
		 $(REMOTE_MAKE) -C "$(REMOTE_RELEASE_TMPDIR)" \
		 package-standalone-macosx \
		 SOURCE_DIST_FILE="$(notdir $(SOURCE_DIST_FILE))" \
		 PACKAGES_DIR="PACKAGES" \
		 VERSION="$(VERSION)"'
	$(verbose) scp -p $(MACOSX_HOST):$(REMOTE_RELEASE_TMPDIR)/PACKAGES/'*' \
		$(PACKAGES_DIR)
	$(verbose) ssh $(SSH_OPTS) $(MACOSX_HOST) \
		'rm -rf $(REMOTE_RELEASE_TMPDIR)'
endif
endif

# The .Net client is built natively on Windows.

# --------------------------------------------------------------------
# Helpers to ease work on the entire components collection.
# --------------------------------------------------------------------

.PHONY: sync-gituser sync-gitremote update-erlang-mk \
	update-rabbitmq-components-mk

sync-gituser:
	$(exec_verbose) global_user_name="$$(git config --global user.name)"; \
	global_user_email="$$(git config --global user.email)"; \
	user_name="$$(git config user.name)"; \
	user_email="$$(git config user.email)"; \
	for repo in $(ALL_DEPS_DIRS); do \
		(cd $$repo && \
		git config --unset user.name; \
		git config --unset user.email; \
		if test "$$global_user_name" != "$$user_name"; then \
			git config user.name "$$user_name"; \
		fi && \
		if test "$$global_user_email" != "$$user_email"; then \
			git config user.email "$$user_email"; \
		fi \
		);\
	done

sync-gitremote:
	$(exec_verbose) fetch_url="$$(git remote -v 2>/dev/null | \
	 awk '/^origin\t.+ \(fetch\)$$/ { print $$2; }' | \
	 sed 's,/rabbitmq-public-umbrella.*,,')"; \
	push_url="$$(git remote -v 2>/dev/null | \
	 awk '/^origin\t.+ \(push\)$$/ { print $$2; }' | \
	 sed 's,/rabbitmq-public-umbrella.*,,')"; \
	for repo in $(ALL_DEPS_DIRS); do \
		(cd $$repo && \
		git remote set-url origin \
		 "$$(git remote -v 2>/dev/null | \
		  awk '/^origin\t.+ \(fetch\)$$/ { print $$2; }' | \
		  sed "s,$(RABBITMQ_REPO_BASE),$${fetch_url},")" && \
		git remote set-url --push origin \
		 "$$(git remote -v 2>/dev/null | \
		  awk '/^origin\t.+ \(push\)$$/ { print $$2; }' | \
		  sed "s,$(RABBITMQ_REPO_BASE),$${push_url},")"; \
		); \
	done

update-erlang-mk: erlang-mk
	$(verbose) if test "$(DO_COMMIT)" = 'yes'; then \
		git diff --quiet -- erlang.mk \
		|| git commit -m 'Update erlang.mk' -- erlang.mk; \
	fi
	$(verbose) for repo in $(ALL_DEPS_DIRS); do \
		! test -f $$repo/erlang.mk \
		|| $(MAKE) -C $$repo erlang-mk; \
		if test "$(DO_COMMIT)" = 'yes'; then \
			(cd $$repo; \
			 git diff --quiet -- erlang.mk \
			 || git commit -m 'Update erlang.mk' -- erlang.mk); \
		fi; \
	done

update-rabbitmq-components-mk: rabbitmq-components-mk
	$(verbose) for repo in $(ALL_DEPS_DIRS); do \
		! test -f $$repo/rabbitmq-components.mk \
		|| $(MAKE) -C $$repo rabbitmq-components-mk; \
	done
