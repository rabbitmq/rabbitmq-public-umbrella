# This is a global include file for all Makefiles. It is expected that modules
# will include it with a command similar to "include ../include.mk". Before
# inclusion, the following variables MUST be set:
#  PACKAGE=    -- The name of the package
# 
# The following optional variables can be set if your build requires it:
#  GENERATED_SOURCES	-- The names of modules that are automatically generated.
#			   Note that the names provided should EXCLUDE the .erl extension 
#  EXTRA_PACKAGE_DIRS   -- The names of extra directories (over ebin) that should be included
#			   in distribution packages

EBIN_DIR=ebin
SOURCE_DIR=src
INCLUDE_DIR=include
DIST_DIR=dist

SHELL=/bin/bash
ERLC=erlc
ERL=erl

INCLUDE_OPTS=-I $(INCLUDE_DIR) $(foreach DEP, $(DEPS), -I ../$(DEP)/include)
SOURCES=$(wildcard $(SOURCE_DIR)/*.erl)
TARGETS=$(foreach GEN, $(GENERATED_SOURCES), src/$(GEN).erl)  \
        $(patsubst $(SOURCE_DIR)/%.erl, $(EBIN_DIR)/%.beam, $(SOURCES)) \
        $(foreach GEN, $(GENERATED_SOURCES), ebin/$(GEN).beam)

ERLC_OPTS=$(INCLUDE_OPTS) -o $(EBIN_DIR) -Wall

RABBIT_SERVER=rabbitmq-server

all: $(TARGETS)

diag:
	echo $(INCLUDE_OPTS)

$(EBIN_DIR)/%.beam: $(SOURCE_DIR)/%.erl
	$(ERLC) $(ERLC_OPTS) -pa $(EBIN_DIR) $<

package: clean all
	rm -rf $(DIST_DIR)
	mkdir -p $(DIST_DIR)/$(PACKAGE)
	cp -r $(EBIN_DIR) $(DIST_DIR)/$(PACKAGE)
	$(foreach EXTRA_DIR, $(EXTRA_PACKAGE_DIRS), cp -r $(EXTRA_DIR) $(DIST_DIR)/$(PACKAGE);)
	(cd $(DIST_DIR); zip -r $(PACKAGE).ez $(PACKAGE))

clean:
	rm -f $(EBIN_DIR)/*.beam
	rm -f erl_crash.dump
	$(foreach GEN, $(GENERATED_SOURCES), rm -f src/$(GEN);)
