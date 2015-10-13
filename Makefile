PROJECT = rabbitmq_public_umbrella

DEPS = $(RABBITMQ_COMPONENTS)

.DEFAULT_GOAL = up

NO_AUTOPATCH_ERLANG_MK = yes
DEP_PLUGINS = rabbit_common/mk/rabbitmq-run.mk

# FIXME: Use erlang.mk patched for RabbitMQ, while waiting for PRs to be
# reviewed and merged.

ERLANG_MK_GIT_REPOSITORY = https://github.com/rabbitmq/erlang.mk.git
ERLANG_MK_GIT_REF = rabbitmq-tmp

include rabbitmq-components.mk
include erlang.mk

# We need to pass the location of codegen to the Java client ant
# process.

CODEGEN_DIR = $(DEPS_DIR)/rabbitmq_codegen
PYTHONPATH = $(CODEGEN_DIR)
ANT ?= ant
ANT_FLAGS += -Dsibling.codegen.dir=$(CODEGEN_DIR) -DUMBRELLA_AVAILABLE=true
RABBITMQCTL = $(DEPS_DIR)/rabbit/scripts/rabbitmqctl
RABBITMQ_TEST_DIR = $(CURDIR)
export PYTHONPATH ANT_FLAGS RABBITMQCTL RABBITMQ_TEST_DIR

.PHONY: co up sync-gituser sync-gitremote status

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

status: .+status $(DEPS:%=$(DEPS_DIR)/%+status)
	@:

%+status: co
	$(exec_verbose) cd $*; \
	git status -s && \
	echo
