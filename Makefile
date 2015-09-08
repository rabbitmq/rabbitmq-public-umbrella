PROJECT = rabbitmq_public_umbrella

DEPS = amqp_client		\
       rabbit			\
       rabbit_common		\
       rabbitmq_codegen		\
       rabbitmq_java_client	\
       rabbitmq_shovel		\
       rabbitmq_test

# For RabbitMQ repositories, we want to checkout branches which match
# the parent porject. For instance, if the parent project is on a
# release tag, dependencies must be on the same release tag. If the
# parent project is on a topic branch, dependencies must be on the same
# topic branch or fallback to `stable` or `master` whichever was the
# base of the topic branch.

ifeq ($(origin current_rmq_ref),undefined)
current_rmq_ref := $(shell git symbolic-ref -q --short HEAD || git describe --tags --exact-match)
export current_rmq_ref
endif
ifeq ($(origin base_rmq_ref),undefined)
base_rmq_ref := $(shell git merge-base --is-ancestor $$(git merge-base master HEAD) stable && echo stable || echo master)
export base_rmq_ref
endif

dep_amqp_client          = git https://github.com/rabbitmq/rabbitmq-erlang-client.git $(current_rmq_ref) $(base_rmq_ref)
dep_rabbit               = git https://github.com/rabbitmq/rabbitmq-server.git $(current_rmq_ref) $(base_rmq_ref)
dep_rabbit_common        = git https://github.com/rabbitmq/rabbitmq-common.git $(current_rmq_ref) $(base_rmq_ref)
dep_rabbitmq_codegen     = git https://github.com/rabbitmq/rabbitmq-codegen.git $(current_rmq_ref) $(base_rmq_ref)
dep_rabbitmq_java_client = git https://github.com/rabbitmq/rabbitmq-java-client.git $(current_rmq_ref) $(base_rmq_ref)
dep_rabbitmq_shovel      = git https://github.com/rabbitmq/rabbitmq-shovel.git $(current_rmq_ref) $(base_rmq_ref)
dep_rabbitmq_test        = git https://github.com/rabbitmq/rabbitmq-test.git $(current_rmq_ref) $(base_rmq_ref)

DEP_PLUGINS = rabbit_common/mk/rabbitmq-run.mk

# FIXME: Use erlang.mk patched for RabbitMQ, while waiting for PRs to be
# reviewed and merged.

ERLANG_MK_GIT_REPOSITORY = https://github.com/rabbitmq/erlang.mk.git
ERLANG_MK_GIT_REF = rabbitmq-tmp

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

.PHONY: co up status

# make co: legacy target.
co: $(ALL_DEPS_DIRS)
	@:

up: .+up $(DEPS:%=$(DEPS_DIR)/%+up)
	@:

%+up: co
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
			git merge --ff-only "$$remote/$$merge" | sed '/^Already up-to-date/d'; \
		fi; \
	fi && \
	echo

status: .+status $(DEPS:%=$(DEPS_DIR)/%+status)
	@:

%+status: co
	$(exec_verbose) cd $*; \
	git status -s && \
	echo
