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
#  EXTRA_TARGETS        -- Additional prerequisites for building the plugin.
#  TEST_SCRIPTS         -- A space seperated list of shell-executable scripts that should be run to
#                          execute plugin tests. Allows languages other than Erlang to be used to write
#                          test cases.
#  TEST_COMMANDS        -- A space separated list of commands that should be executed in order to run
#                          test cases. For example, my_module_tests:test()
#                          Beware of quote escaping issues!
#  ROOT_DIR             -- The path to the public_umbrella. Default is ..
#  LOG_IN_FILE (deprecate)

VERSION=0.0.0
EBIN_DIR=ebin
TEST_EBIN_DIR=test_ebin
SOURCE_DIR=src
TEST_DIR=test
INCLUDE_DIR=include
DIST_DIR=dist
DEPS_DIR=deps
PRIV_DEPS_DIR=build/deps
ROOT_DIR ?=..

SHELL ?= /bin/bash
ERLC ?= erlc
ERL ?= erl
ERL_CALL ?= erl_call

TMPDIR ?= /tmp
PLUGINS_TMP ?= $(TMPDIR)/plugins-umbrella

LIBS_PATH_DEPS := $(PRIV_DEPS_DIR):$(DEPS_DIR)

ifeq ("$(ERL_LIBS)", "")
    LIBS_PATH_UNIX := $(LIBS_PATH_DEPS)
else
    LIBS_PATH_UNIX := $(LIBS_PATH_DEPS):$(ERL_LIBS)
endif

IS_CYGWIN := $(shell if [ $(shell expr "$(shell uname -s)" : 'CYGWIN_NT') -gt 0 ]; then echo "true"; else echo "false"; fi)

ifeq ($(IS_CYGWIN),true)
    LIBS_PATH := "$(shell cygpath -wp $(LIBS_PATH_UNIX))"
else
    LIBS_PATH := $(LIBS_PATH_UNIX)
endif

INCLUDES=$(wildcard $(INCLUDE_DIR)/*.hrl)
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
	$(EBIN_DIR)/$(APPNAME).app \
	$(EXTRA_TARGETS)
TEST_TARGETS=$(patsubst $(TEST_DIR)/%.erl, $(TEST_EBIN_DIR)/%.beam, $(TEST_SOURCES))

NODE_NAME=rabbit

ERLC_OPTS=$(INCLUDE_OPTS) -o $(EBIN_DIR) -Wall +debug_info
TEST_ERLC_OPTS=$(INCLUDE_OPTS) -o $(TEST_EBIN_DIR) -Wall
ERL_CALL_OPTS=-sname $(NODE_NAME) -e

INCLUDE_OPTS=-I $(INCLUDE_DIR)

LOG_BASE=$(TMPDIR)

INFILES=$(shell find . -name '*.app.in')
INTARGETS=$(patsubst %.in, %, $(INFILES))

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
	ERL_LIBS=$(LIBS_PATH) $(ERLC) $(ERLC_OPTS) -pa $(EBIN_DIR) $<

$(TEST_EBIN_DIR):
	mkdir -p $(TEST_EBIN_DIR)

$(TEST_EBIN_DIR)/%.beam: $(TEST_DIR)/%.erl
	@mkdir -p $(TEST_EBIN_DIR)
	ERL_LIBS=$(LIBS_PATH) $(ERLC) $(TEST_ERLC_OPTS) -pa $(TEST_EBIN_DIR) $<

$(DEPS_DIR)/%/ebin:
	$(MAKE) -C $(shell dirname $@)

$(PRIV_DEPS_DIR)/%/ebin:
	@mkdir -p $(PRIV_DEPS_DIR)
	$(foreach EZ, $(DEP_EZS), cp $(EZ) $(PRIV_DEPS_DIR) &&) true
	(cd $(PRIV_DEPS_DIR); unzip $*.ez)

%.app: %.app.in
	sed -e 's:%%VSN%%:$(VERSION):g' < $< > $@

list-deps:
	@echo $(foreach DEP, $(INTERNAL_DEPS), $(DEPS_DIR)/$(DEP))

echo-package-name:
	@echo $(PACKAGE)

package: $(DIST_DIR)/$(PACKAGE).ez $(EXTRA_PACKAGES)

$(DIST_DIR)/$(PACKAGE).ez: $(TARGETS)
	rm -rf $(DIST_DIR)
	mkdir -p $(DIST_DIR)/$(PACKAGE)
	cp -r $(EBIN_DIR) $(DIST_DIR)/$(PACKAGE)
	$(foreach EXTRA_DIR, $(EXTRA_PACKAGE_DIRS), cp -r $(EXTRA_DIR) $(DIST_DIR)/$(PACKAGE);)
	(cd $(DIST_DIR); zip -r $(PACKAGE).ez $(PACKAGE))
	$(foreach DEP, $(INTERNAL_DEPS), cp $(DEPS_DIR)/$(DEP)/$(DEP).ez $(DIST_DIR);)
	$(foreach DEP, $(DEP_NAMES), cp $(PRIV_DEPS_DIR)/$(DEP).ez $(DIST_DIR) &&) true

.PHONY: cover coverage test run plugins-dir

COVER_DIR=.
cover: coverage
coverage:
	$(MAKE) test BOOT_CMDS='cover:start() rabbit_misc:enable_cover([\"$(COVER_DIR)\"])' CLEANUP_CMDS='rabbit_misc:report_cover() cover:stop()'
	@echo -e "\n**** Code coverage ****"
	@cat cover/summary.txt

test:	$(TARGETS) $(TEST_TARGETS) plugins-dir
	RABBITMQ_TEST_EBIN=`pwd`/$(TEST_EBIN_DIR) \
	  RABBITMQ_PLUGINS_DIR=$(PLUGINS_TMP) \
	  RABBITMQ_LOG_BASE=$(LOG_BASE) RABBITMQ_MNESIA_DIR=tmp \
	  ../rabbitmq-server/scripts/rabbitmq-server run & sleep 2
	echo >$(TMPDIR)/rabbit-test-output && \
	{ $(foreach BOOT_CMD,$(BOOT_CMDS),\
            echo "$(BOOT_CMD)." | tee -a $(TMPDIR)/rabbit-test-output | $(ERL_CALL) $(ERL_CALL_OPTS) | tee -a $(TMPDIR)/rabbit-test-output | egrep "{ok, " >/dev/null && ) true && \
	  $(foreach CMD,$(TEST_COMMANDS), \
	    echo >>$(TMPDIR)/rabbit-test-output && \
	    echo "$(CMD)." | tee -a $(TMPDIR)/rabbit-test-output | $(ERL_CALL) $(ERL_CALL_OPTS) | tee -a $(TMPDIR)/rabbit-test-output | egrep "{ok, " >/dev/null && ) true && \
	  $(foreach SCRIPT,$(TEST_SCRIPTS), \
	    $(SCRIPT) && ) true || OK=false; } && \
	{ $$OK || cat $(TMPDIR)/rabbit-test-output; echo; } && \
	$(foreach CLEANUP_CMD,$(CLEANUP_CMDS),\
            echo "$(CLEANUP_CMD)." | tee -a $(TMPDIR)/rabbit-test-output | $(ERL_CALL) $(ERL_CALL_OPTS) | tee -a $(TMPDIR)/rabbit-test-output | egrep "{ok, " >/dev/null; ) true && \
	sleep 1 && \
	make -C ../rabbitmq-server stop-node && \
	$$OK

run:	$(TARGETS) $(TEST_TARGETS) plugins-dir
	RABBITMQ_PLUGINS_DIR=$(PLUGINS_TMP) make -C ../rabbitmq-server run

plugins-dir:
	rm -rf $(PLUGINS_TMP)
	mkdir -p $(PLUGINS_TMP)
	for file in $(DEPS_DIR)/* ; do ln -s `pwd`/$$file/`basename $$file` $(PLUGINS_TMP) ; done
	for file in $(PRIV_DEPS_DIR)/* ; do ln -s `pwd`/$$file $(PLUGINS_TMP) ; done
	ln -s `pwd` $(PLUGINS_TMP)/$(PACKAGE)
	rm -f $(PLUGINS_TMP)/rabbit_common
	rm -f $(PLUGINS_TMP)/*.ez

clean::
	rm -f $(EBIN_DIR)/*.beam
	rm -f $(TEST_EBIN_DIR)/*.beam
	rm -f erl_crash.dump
	rm -rf $(PRIV_DEPS_DIR)
	$(foreach GEN, $(GENERATED_SOURCES), rm -f src/$(GEN).erl;)
	$(foreach DEP, $(INTERNAL_DEPS), $(MAKE) -C $(DEPS_DIR)/$(DEP) clean;)
	rm -rf $(DIST_DIR)
	rm -f $(INTARGETS)

distclean:: clean
	$(foreach DEP, $(INTERNAL_DEPS), $(MAKE) -C $(DEPS_DIR)/$(DEP) distclean;)
