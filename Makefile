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
# Helpers to work on RabbitMQ inside Docker.
# --------------------------------------------------------------------

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
