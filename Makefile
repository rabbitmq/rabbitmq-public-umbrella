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

# We need to pass the location of codegen to the Java client ant
# process.

CODEGEN_DIR = $(DEPS_DIR)/rabbitmq_codegen
PYTHONPATH = $(CODEGEN_DIR)
ANT ?= ant
ANT_FLAGS += -Dsibling.codegen.dir=$(CODEGEN_DIR)
RABBITMQCTL = $(DEPS_DIR)/rabbit/scripts/rabbitmqctl
RABBITMQ_TEST_DIR = $(CURDIR)
export PYTHONPATH ANT_FLAGS RABBITMQCTL RABBITMQ_TEST_DIR

READY_DEPS = $(foreach DEP,$(DEPS), \
	     $(if $(wildcard $(DEPS_DIR)/$(DEP)),$(DEP),))

.PHONY: co up status

# make co: legacy target.
co: fetch-deps
	@:

up: .+up $(DEPS:%=$(DEPS_DIR)/%+up)
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
			git merge --ff-only "$$remote/$$merge" \
			 | sed '/^Already up-to-date/d'; \
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
		git config --unset user.name && \
		git config --unset user.email && \
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
