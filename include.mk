# This is a global include file for all Makefiles. It is expected that modules
# will include it with a command similar to "include ../include.mk". Before
# inclusion, the following variables MUST be set:
#  PACKAGE=    -- The name of the package
#
# The following optional variables can be set if your build requires it:
#  DEPS                 -- Other projects that your build depends on (eg rabbitmq-server)
#  INTERNAL_DEPS        -- Internal dependencies that need to be built and included.
#  GENERATED_SOURCES	-- The names of modules that are automatically generated.
#			   Note that the names provided should EXCLUDE the .erl extension
#  EXTRA_PACKAGE_DIRS   -- The names of extra directories (over ebin) that should be included
#			   in distribution packages
#  EXTRA_PACKAGE_ARTIFACTS -- The names of additional artifacts that are produced as part of
#                             the packaging process. Files will be created in dist/, but the
#                             name listed here should exclude the dist/ prefix.
#  TEST_APPS            -- Applications that should be started as part of the VM that your tests
#                          run in
#  TEST_SCRIPTS         -- A space seperated list of shell-executable scripts that should be run to
#                          execute plugin tests. Allows languages other than Erlang to be used to write
#                          test cases.
#  START_RABBIT_IN_TESTS -- If set, a Rabbit broker instance will be started as part of the test VM
#  TEST_COMMANDS        -- A space separated list of commands that should be executed in order to run
#                          test cases. For example, my_module_tests:test()
#  TEST_ARGS            -- Appended to the erl command line when running or running tests.
#                          Beware of quote escaping issues!

EBIN_DIR=ebin
TEST_EBIN_DIR=test_ebin
SOURCE_DIR=src
TEST_DIR=test
INCLUDE_DIR=include
DIST_DIR=dist
DEPS_DIR=deps
PRIV_DEPS_DIR=build/deps
ROOT_DIR=..

SHELL ?= /bin/bash
ERLC ?= erlc
ERL ?= erl
ERL_CALL ?= erl_call

TMPDIR ?= /tmp

SOURCES=$(wildcard $(SOURCE_DIR)/*.erl)
TEST_SOURCES=$(wildcard $(TEST_DIR)/*.erl)
DEP_EZS=$(foreach DEP, $(DEPS), $(wildcard $(ROOT_DIR)/$(DEP)/$(DIST_DIR)/*.ez))
DEP_NAMES=$(patsubst %.ez, %, $(foreach DEP_EZ, $(DEP_EZS), $(shell basename $(DEP_EZ))))

EXTRA_PACKAGES=$(foreach PACKAGE_NAME, $(EXTRA_PACKAGE_ARTIFACTS), $(DIST_DIR)/$(PACKAGE_NAME))

EXTRA_TARGETS ?=

TARGETS=$(foreach DEP, $(INTERNAL_DEPS), $(DEPS_DIR)/$(DEP)/ebin) \
	$(foreach DEP_NAME, $(DEP_NAMES), $(PRIV_DEPS_DIR)/$(DEP_NAME)/ebin) \
        $(patsubst $(SOURCE_DIR)/%.erl, $(EBIN_DIR)/%.beam, $(SOURCES)) \
        $(foreach GEN, $(GENERATED_SOURCES), ebin/$(GEN).beam) \
	$(EXTRA_TARGETS)
TEST_TARGETS=$(patsubst $(TEST_DIR)/%.erl, $(TEST_EBIN_DIR)/%.beam, $(TEST_SOURCES))

NODE_NAME=rabbit

ERLC_OPTS=$(INCLUDE_OPTS) -o $(EBIN_DIR) -Wall +debug_info
TEST_ERLC_OPTS=$(INCLUDE_OPTS) -o $(TEST_EBIN_DIR) -Wall
ERL_CALL_OPTS=-sname $(NODE_NAME) -e

DEPS_LOAD_PATH=$(foreach DEP, $(DEP_NAMES), -pa $(PRIV_DEPS_DIR)/$(DEP)/ebin) \
	$(foreach DEP, $(INTERNAL_DEPS), -pa $(DEPS_DIR)/$(DEP)/ebin)
TEST_LOAD_PATH=-pa $(EBIN_DIR) -pa $(TEST_EBIN_DIR) $(DEPS_LOAD_PATH)

INCLUDE_OPTS=-I $(INCLUDE_DIR) $(DEPS_LOAD_PATH)

LOG_BASE=$(TMPDIR)
LOG_IN_FILE=true
RABBIT_SERVER=rabbitmq-server
ADD_BROKER_ARGS=-pa $(ROOT_DIR)/$(RABBIT_SERVER)/ebin -mnesia dir tmp -boot start_sasl \
        $(shell [ $(LOG_IN_FILE) = "true" ] && echo "-sasl sasl_error_logger '{file, \"'${LOG_BASE}'/rabbit-sasl.log\"}' -kernel error_logger '{file, \"'${LOG_BASE}'/rabbit.log\"}'") \
	-os_mon start_memsup false
ifeq ($(START_RABBIT_IN_TESTS),)
FULL_TEST_ARGS=$(TEST_ARGS)
FULL_BOOT_CMDS=$(BOOT_CMDS)
else
FULL_TEST_ARGS=$(ADD_BROKER_ARGS) $(TEST_ARGS)
FULL_BOOT_CMDS=$(BOOT_CMDS) rabbit:start()
endif
FULL_CLEANUP_CMDS=$(CLEANUP_CMDS) init:stop()


TEST_APP_ARGS=$(foreach APP,$(TEST_APPS),-eval 'ok = application:start($(APP))')

all: package

diag:
	@echo DEP_EZS=$(DEP_EZS)
	@echo DEP_NAMES=$(DEP_NAMES)
	@echo TARGETS=$(TARGETS)
	@echo INCLUDE_OPTS=$(INCLUDE_OPTS)

$(EBIN_DIR):
	mkdir -p $(EBIN_DIR)

$(EBIN_DIR)/%.beam: $(SOURCE_DIR)/%.erl
	@mkdir -p $(EBIN_DIR)
	$(ERLC) $(ERLC_OPTS) -pa $(EBIN_DIR) $<

$(TEST_EBIN_DIR):
	mkdir -p $(TEST_EBIN_DIR)

$(TEST_EBIN_DIR)/%.beam: $(TEST_DIR)/%.erl
	@mkdir -p $(TEST_EBIN_DIR)
	$(ERLC) $(TEST_ERLC_OPTS) -pa $(TEST_EBIN_DIR) $<

$(DEPS_DIR)/%/ebin:
	$(MAKE) -C $(shell dirname $@)

$(PRIV_DEPS_DIR)/%/ebin:
	@mkdir -p $(PRIV_DEPS_DIR)
	$(foreach EZ, $(DEP_EZS), cp $(EZ) $(PRIV_DEPS_DIR) &&) true
	(cd $(PRIV_DEPS_DIR); unzip $*.ez)

list-deps:
	@echo $(foreach DEP, $(INTERNAL_DEPS), $(DEPS_DIR)/$(DEP))

package: $(DIST_DIR)/$(PACKAGE).ez $(EXTRA_PACKAGES)

$(DIST_DIR)/$(PACKAGE).ez: $(TARGETS)
	rm -rf $(DIST_DIR)
	mkdir -p $(DIST_DIR)/$(PACKAGE)
	cp -r $(EBIN_DIR) $(DIST_DIR)/$(PACKAGE)
	$(foreach EXTRA_DIR, $(EXTRA_PACKAGE_DIRS), cp -r $(EXTRA_DIR) $(DIST_DIR)/$(PACKAGE);)
	(cd $(DIST_DIR); zip -r $(PACKAGE).ez $(PACKAGE))
	$(foreach DEP, $(INTERNAL_DEPS), cp $(DEPS_DIR)/$(DEP)/$(DEP).ez $(DIST_DIR))
	$(foreach DEP, $(DEP_NAMES), cp $(PRIV_DEPS_DIR)/$(DEP).ez $(DIST_DIR) &&) true


COVER_DIR=.
cover: coverage
coverage:
	$(MAKE) test BOOT_CMDS='cover:start() rabbit_misc:enable_cover([\"$(COVER_DIR)\"])' CLEANUP_CMDS='rabbit_misc:report_cover() cover:stop()'
	@echo -e "\n**** Code coverage ****"
	@cat cover/summary.txt


test:	$(TARGETS) $(TEST_TARGETS)
	OK=true && \
	echo >$(TMPDIR)/rabbit-test-output && \
	{ $(ERL) $(TEST_LOAD_PATH) -noshell -sname $(NODE_NAME) $(FULL_TEST_ARGS) & sleep 1 && \
	  $(foreach BOOT_CMD,$(FULL_BOOT_CMDS),\
            echo "$(BOOT_CMD)." | tee -a $(TMPDIR)/rabbit-test-output | $(ERL_CALL) $(ERL_CALL_OPTS) | tee -a $(TMPDIR)/rabbit-test-output | egrep "{ok, " >/dev/null && ) true && \
	  $(foreach APP,$(TEST_APPS),\
	    echo >>$(TMPDIR)/rabbit-test-output && \
            echo "ok = application:start($(APP))." | tee -a $(TMPDIR)/rabbit-test-output | $(ERL_CALL) $(ERL_CALL_OPTS) | tee -a $(TMPDIR)/rabbit-test-output | egrep "{ok, " >/dev/null && ) true && \
	  $(foreach CMD,$(TEST_COMMANDS), \
	    echo >>$(TMPDIR)/rabbit-test-output && \
	    echo "$(CMD)." | tee -a $(TMPDIR)/rabbit-test-output | $(ERL_CALL) $(ERL_CALL_OPTS) | tee -a $(TMPDIR)/rabbit-test-output | egrep "{ok, " >/dev/null && ) true && \
	  $(foreach SCRIPT,$(TEST_SCRIPTS), \
	    $(SCRIPT) && ) true || OK=false; } && \
	{ $$OK || cat $(TMPDIR)/rabbit-test-output; echo; } && \
	$(foreach CLEANUP_CMD,$(FULL_CLEANUP_CMDS),\
            echo "$(CLEANUP_CMD)." | tee -a $(TMPDIR)/rabbit-test-output | $(ERL_CALL) $(ERL_CALL_OPTS) | tee -a $(TMPDIR)/rabbit-test-output | egrep "{ok, " >/dev/null; ) true && \
	sleep 1 && \
	$$OK

run:	$(TARGETS) $(TEST_TARGETS)
	$(ERL) $(TEST_LOAD_PATH) $(FULL_TEST_ARGS) -sname $(NODE_NAME) $(foreach BOOT_CMD,$(FULL_BOOT_CMDS),-eval '$(BOOT_CMD)') $(TEST_APP_ARGS)

clean::
	rm -f $(EBIN_DIR)/*.beam
	rm -f $(TEST_EBIN_DIR)/*.beam
	rm -f erl_crash.dump
	rm -rf $(PRIV_DEPS_DIR)
	$(foreach GEN, $(GENERATED_SOURCES), rm -f src/$(GEN).erl;)
	$(foreach DEP, $(INTERNAL_DEPS), $(MAKE) -C $(DEPS_DIR)/$(DEP) clean)
	rm -rf $(DIST_DIR)
