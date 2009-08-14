# This is a global include file for all Makefiles. It is expected that modules
# will include it with a command similar to "include ../include.mk". Before
# inclusion, the following variables MUST be set:
#  PACKAGE=    -- The name of the package
# 
# The following optional variables can be set if your build requires it:
#  DEPS                 -- Other projects that your build depends on (eg rabbitmq-server)
#  DEP_APPS             -- The application names of dependencies that should be added to the load path
#  INTERNAL_DEPS        -- Internal dependencies that need to be built and included.
#  GENERATED_SOURCES	-- The names of modules that are automatically generated.
#			   Note that the names provided should EXCLUDE the .erl extension 
#  EXTRA_PACKAGE_DIRS   -- The names of extra directories (over ebin) that should be included
#			   in distribution packages
#  TEST_APPS            -- Applications that should be started as part of the VM that your tests
#                          run in
#  START_RABBIT_IN_TESTS -- If set, a Rabbit broker instance will be started as part of the test VM

EBIN_DIR=ebin
TEST_EBIN_DIR=test_ebin
SOURCE_DIR=src
TEST_DIR=test
INCLUDE_DIR=include
DIST_DIR=dist
DEPS_DIR=deps
PRIV_DEPS_DIR=priv/deps
ROOT_DIR=..

SHELL=/bin/bash
ERLC=erlc
ERL=erl

SOURCES=$(wildcard $(SOURCE_DIR)/*.erl)
TEST_SOURCES=$(wildcard $(TEST_DIR)/*.erl)
TARGETS=$(foreach DEP, $(INTERNAL_DEPS), $(DEPS_DIR)/$(DEP)/ebin) \
	$(foreach DEP, $(DEP_APPS), $(PRIV_DEPS_DIR)/$(DEP)/ebin) \
	$(foreach GEN, $(GENERATED_SOURCES), src/$(GEN).erl)  \
        $(patsubst $(SOURCE_DIR)/%.erl, $(EBIN_DIR)/%.beam, $(SOURCES)) \
        $(foreach GEN, $(GENERATED_SOURCES), ebin/$(GEN).beam)
TEST_TARGETS=$(patsubst $(TEST_DIR)/%.erl, $(TEST_EBIN_DIR)/%.beam, $(TEST_SOURCES))

ERLC_OPTS=$(INCLUDE_OPTS) -o $(EBIN_DIR) -Wall
TEST_ERLC_OPTS=$(INCLUDE_OPTS) -o $(TEST_EBIN_DIR) -Wall

DEPS_LOAD_PATH=$(foreach DEP, $(DEP_APPS), -pa $(PRIV_DEPS_DIR)/$(DEP)/ebin) \
	$(foreach DEP, $(INTERNAL_DEPS), -pa $(DEPS_DIR)/$(DEP)/ebin) \
	$(foreach DEP, $(DEPS), $(foreach SUBDEP, $(shell [ -d $(ROOT_DIR)/$(DEP)/deps ] && ls $(ROOT_DIR)/$(DEP)/deps), -pa $(ROOT_DIR)/$(DEP)/deps/$(SUBDEP)/ebin))
TEST_LOAD_PATH=-pa $(EBIN_DIR) -pa $(TEST_EBIN_DIR) $(DEPS_LOAD_PATH)

INCLUDE_OPTS=-I $(INCLUDE_DIR) $(foreach DEP, $(DEPS), -I $(ROOT_DIR)/$(DEP)/include) \
             $(foreach DEP, $(INTERNAL_DEPS), -I $(DEPS_DIR)/$(DEP)/include) \
             $(DEPS_LOAD_PATH)

LOG_BASE=/tmp
LOG_IN_FILE=true
RABBIT_SERVER=rabbitmq-server
ADD_BROKER_ARGS=-mnesia dir tmp -boot start_sasl -s rabbit -sname rabbit\
        $(shell [ $(LOG_IN_FILE) = "true" ] && echo "-sasl sasl_error_logger '{file, \"'${LOG_BASE}'/rabbit-sasl.log\"}' -kernel error_logger '{file, \"'${LOG_BASE}'/rabbit.log\"}'")
ifeq ($(START_RABBIT_IN_TESTS),)
TEST_ARGS=
else
TEST_ARGS=$(ADD_BROKER_ARGS)
endif

TEST_APP_ARGS=$(foreach APP,$(TEST_APPS),-eval 'ok = application:start($(APP))')

all: $(TARGETS)

diag:
	echo $(INCLUDE_OPTS)

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
	$(foreach DEP, $(DEPS), $(foreach EZ, $(shell ls $(ROOT_DIR)/$(DEP)/dist/*.ez), cp $(EZ) $(PRIV_DEPS_DIR);))
	(cd $(PRIV_DEPS_DIR); unzip $*.ez)

list-deps:
	@echo $(foreach DEP, $(INTERNAL_DEPS), $(DEPS_DIR)/$(DEP))

package: clean all
	rm -rf $(DIST_DIR)
	mkdir -p $(DIST_DIR)/$(PACKAGE)
	cp -r $(EBIN_DIR) $(DIST_DIR)/$(PACKAGE)
	$(foreach EXTRA_DIR, $(EXTRA_PACKAGE_DIRS), cp -r $(EXTRA_DIR) $(DIST_DIR)/$(PACKAGE);)
	(cd $(DIST_DIR); zip -r $(PACKAGE).ez $(PACKAGE))
	$(foreach DEP, $(INTERNAL_DEPS), cp $(DEPS_DIR)/$(DEP)/$(DEP).ez $(DIST_DIR))

test:	$(TARGETS) $(TEST_TARGETS)
	$(ERL) $(TEST_LOAD_PATH) -noshell $(TEST_ARGS) $(TEST_APP_ARGS) -eval "$(foreach CMD,$(TEST_COMMANDS),$(CMD), )halt()."	

run:	$(TARGETS) $(TEST_TARGETS)
	$(ERL) $(TEST_LOAD_PATH) $(TEST_ARGS) $(TEST_APP_ARGS)

clean:
	rm -f $(EBIN_DIR)/*.beam
	rm -f $(TEST_EBIN_DIR)/*.beam
	rm -f erl_crash.dump
	rm -rf $(PRIV_DEPS_DIR)
	$(foreach GEN, $(GENERATED_SOURCES), rm -f src/$(GEN);)
	$(foreach DEP, $(INTERNAL_DEPS), $(MAKE) -C $(DEPS_DIR)/$(DEP) clean)
