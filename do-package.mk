# This file produces the makefile fragment associated with a package,
# and the dependencies of that package that have not already been
# visited.
#
# PACKAGE_DIR should be set to the canonical path of the package.

# Mark that this package has been visited, so we can avoid doing it again
DONE_$(PACKAGE_DIR):=true

# Declare the standard per-package targets
.PHONY: $(PACKAGE_DIR)+dist $(PACKAGE_DIR)+clean $(PACKAGE_DIR)+clean-recursive

$(PACKAGE_DIR)+dist:: $(PACKAGE_DIR)/dist/.done

$(PACKAGE_DIR)+clean::

$(PACKAGE_DIR)+clean-with-deps:: $(PACKAGE_DIR)+clean

# Hook into the "all package" targets used by the main public-umbrella
# makefile
all-packages:: $(PACKAGE_DIR)/dist/.done
clean-all-packages:: $(PACKAGE_DIR)+clean

ifndef NON_INTEGRATED_$(PACKAGE_DIR)

# Set all the per-package vars to their default values

SOURCE_DIRS:=$(PACKAGE_DIR)/src
SOURCE_ERLS=$(foreach D,$(SOURCE_DIRS),$(wildcard $(D)/*.erl))

INCLUDE_DIRS:=$(PACKAGE_DIR)/include
INCLUDE_HRLS=$(foreach D,$(INCLUDE_DIRS),$(wildcard $(D)/*.hrl))

EBIN_DIR:=$(PACKAGE_DIR)/ebin
EBIN_BEAMS=$(patsubst %,$(EBIN_DIR)/%.beam,$(notdir $(basename $(SOURCE_ERLS))))

PACKAGE_NAME=$(notdir $(abspath $(PACKAGE_DIR)))
APP_NAME=$(call package_to_app_name,$(PACKAGE_NAME))
DEPS_FILE=$(PACKAGE_DIR)/build/deps.mk
PACKAGE_VERSION=$(VERSION)

ORIGINAL_APP_FILE=$(EBIN_DIR)/$(APP_NAME).app

EXTRA_PACKAGE_DIRS:=
EXTRA_TARGETS:=

ERLC_OPTS:=

RELEASABLE:=

DEPS:=

TEST_DIR=$(PACKAGE_DIR)/test
TEST_SOURCE_DIRS=$(TEST_DIR)/src
TEST_SOURCE_ERLS=$(foreach D,$(TEST_SOURCE_DIRS),$(wildcard $(D)/*.erl))
TEST_EBIN_DIR=$(TEST_DIR)/ebin
TEST_EBIN_BEAMS=$(patsubst %,$(TEST_EBIN_DIR)/%.beam,$(notdir $(basename $(TEST_SOURCE_ERLS))))
TEST_COMMANDS:=
TEST_SCRIPTS:=

# Wrapper package vars

# Set one of these to say where the upstream repo lives
UPSTREAM_GIT:=
UPSTREAM_HG:=

UPSTREAM_TYPE=$(if $(UPSTREAM_GIT),git)$(if $(UPSTREAM_HG),hg)

# The upstream revision to use.  Leave empty for default or master
UPSTREAM_REVISION:=

# Patches to apply to the upstream codebase, if any
WRAPPER_PATCHES:=

# Should the app version retain the version from the original .app file?
RETAIN_ORIGINAL_VERSION:=
ORIGINAL_VERSION:=

# Where to clone the upstream to.
CLONE_DIR=$(PACKAGE_DIR)/$(patsubst %-wrapper,%,$(PACKAGE_NAME))-$(UPSTREAM_TYPE)

# Where the upstream's usual directories are
UPSTREAM_SOURCE_DIRS=$(CLONE_DIR)/src
UPSTREAM_INCLUDE_DIRS=$(CLONE_DIR)/include

package_targets=

# Now let the package makefile fragment do its stuff
include $(PACKAGE_DIR)/package.mk

# package_targets provides a convenient way to force prompt expansion
# of variables, including expansion in commands that would otherwise
# be deferred.
#
# If package_targets is defined by the package makefile, we expand it
# and eval it.  The point here is to get around the fact that make
# defers expansion of commands.  But if we use package variables in
# targets, as we naturally want to do, deferred expansion doesn't
# work: They might have been trampled on by a later package.  Because
# we expand package_targets here, references to package varialbes will
# get expanded with the values we expect.
#
# The downside is that any variable references for which expansion
# really should be deferred need to be protected by doulbing up the
# dollar.  E.g., inside package_targets, you should write $$@, not $@.
#
# We use the same trick again below.
ifdef package_targets
$(eval $(package_targets))
endif

# Some variables used for brevity below.  Packages can't set these.
APP_FILE=$(PACKAGE_DIR)/build/$(APP_NAME).app.$(PACKAGE_VERSION)
APP_DONE=$(PACKAGE_DIR)/build/app/.done.$(PACKAGE_VERSION)

# Handle RETAIN_ORIGINAL_VERSION / ORIGINAL_VERSION
ifdef RETAIN_ORIGINAL_VERSION

# Automatically acquire ORIGINAL_VERSION from ORIGINAL_APP_FILE
ifndef ORIGINAL_VERSION

# The generated ORIGINAL_VERSION setting goes in build/version.mk
$(eval $(call safe_include,$(PACKAGE_DIR)/build/version.mk))

$(PACKAGE_DIR)/build/version.mk: $(ORIGINAL_APP_FILE)
	sed -n -e 's|^.*{vsn, *"\([^"]*\)".*$$|ORIGINAL_VERSION:=\1|p' <$< >$@

$(APP_FILE): $(PACKAGE_DIR)/build/version.mk

endif # ifndef ORIGINAL_VERSION

PACKAGE_VERSION:=$(ORIGINAL_VERSION)-rmq$(VERSION)

endif # ifdef RETAIN_ORIGINAL_VERSION

# Handle wrapper packages
ifneq ($(UPSTREAM_TYPE),)

SOURCE_DIRS+=$(UPSTREAM_SOURCE_DIRS)
INCLUDE_DIRS+=$(UPSTREAM_INCLUDE_DIRS)

define package_targets

ifdef UPSTREAM_GIT
$(CLONE_DIR)/.done:
	rm -rf $(CLONE_DIR)
	git clone $(UPSTREAM_GIT) $(CLONE_DIR)
	$(if $(UPSTREAM_REVISION),cd $(CLONE_DIR) && git checkout $(UPSTREAM_REVISION))
	$(if $(WRAPPER_PATCHES),$(foreach F,$(WRAPPER_PATCHES),patch -d $(CLONE_DIR) -p1 <$(PACKAGE_DIR)/$(F) &&) :)
	touch $$@
endif # UPSTREAM_GIT

ifdef UPSTREAM_HG
$(CLONE_DIR)/.done:
	rm -rf $(CLONE_DIR)
	hg clone -r $(or $(UPSTREAM_REVISION),default) $(UPSTREAM_HG) $(CLONE_DIR)
	$(if $(WRAPPER_PATCHES),$(foreach F,$(WRAPPER_PATCHES),patch -d $(CLONE_DIR) -p1 <$(PACKAGE_DIR)/$(F) &&) :)
	touch $$@
endif # UPSTREAM_HG

# When we clone, we need to remake anything derived from the app file
# (e.g. build/version.mk).
$(ORIGINAL_APP_FILE): $(CLONE_DIR)/.done

# We include the commit hash into the package version, via
# build/hash.mk
$(eval $(call safe_include,$(PACKAGE_DIR)/build/hash.mk))

$(PACKAGE_DIR)/build/hash.mk: $(CLONE_DIR)/.done
	@mkdir -p $$(@D)
ifdef UPSTREAM_GIT
	echo UPSTREAM_SHORT_HASH:=`git --git-dir=$(CLONE_DIR)/.git log -n 1 --format=format:"%h" HEAD` >$$@
endif
ifdef UPSTREAM_HG
	echo UPSTREAM_SHORT_HASH:=`hg id -R $(CLONE_DIR) -i | cut -c -7` >$$@
endif

$(APP_FILE): $(PACKAGE_DIR)/build/hash.mk

PACKAGE_VERSION:=$(PACKAGE_VERSION)-$(UPSTREAM_TYPE)$(UPSTREAM_SHORT_HASH)

$(PACKAGE_DIR)+clean::
	rm -rf $(CLONE_DIR)
endef # package_targets
$(eval $(package_targets))

endif # UPSTREAM_TYPE

# Convert the DEPS package names to canonical paths
DEP_PATHS:=$(foreach DEP,$(DEPS),$(call package_to_path,$(DEP)))

APP_DIR:=$(PACKAGE_DIR)/build/app/$(APP_NAME)-$(PACKAGE_VERSION)
EZ_FILE:=$(PACKAGE_DIR)/dist/$(APP_NAME)-$(PACKAGE_VERSION).ez

# Generate a rule to compile .erl files from the directory $(1) into
# directory $(2), taking extra erlc options from $(3)
define package_source_dir_targets
$(2)/%.beam: $(1)/%.erl $(PACKAGE_DIR)/build/dep-apps/.done | $(DEPS_FILE)
	@mkdir -p $$(@D)
	ERL_LIBS=$(PACKAGE_DIR)/build/dep-apps $(ERLC) $(ERLC_OPTS) $(GLOBAL_ERLC_OPTS) $(foreach D,$(INCLUDE_DIRS),-I $(D) )-pa $$(@D) -o $$(@D) $(3) $$<

endef

$(eval $(foreach D,$(SOURCE_DIRS),$(call package_source_dir_targets,$(D),$(EBIN_DIR),)))
$(eval $(foreach D,$(TEST_SOURCE_DIRS),$(call package_source_dir_targets,$(D),$(TEST_EBIN_DIR),-pa $(EBIN_DIR))))

# Commands to run the broker for tests
#
# $(1): The value for RABBITMQ_SERVER_START_ARGS
# $(2): Extra env var settings when invoking the rabbitmq-server script
# $(3): Extra .ezs to copy into the plugins dir
define run_broker
	rm -rf $(TEST_TMPDIR)
	mkdir -p $(foreach D,log plugins $(NODENAME),$(TEST_TMPDIR)/$(D))
	cp -a $(PACKAGE_DIR)/dist/*.ez $(TEST_TMPDIR)/plugins
	$(call copy,$(3),$(TEST_TMPDIR)/plugins)
	rm -f $(TEST_TMPDIR)/plugins/rabbit_common*.ez
	RABBITMQ_PLUGINS_DIR=$(TEST_TMPDIR)/plugins \
	  RABBITMQ_LOG_BASE=$(TEST_TMPDIR)/log \
	  RABBITMQ_MNESIA_BASE=$(TEST_TMPDIR)/$(NODENAME) \
	  RABBITMQ_NODENAME=$(NODENAME) \
	  RABBITMQ_SERVER_START_ARGS=$(1) \
	  $(2) $(UMBRELLA_BASE_DIR)/rabbitmq-server/scripts/rabbitmq-server
endef

# Commands to run the package's test suite
#
# $(1): Extra .ezs to copy into the plugins dir
define run_in_broker_tests
$(if $(IN_BROKER_TEST_COMMANDS)$(IN_BROKER_TEST_SCRIPTS),$(call run_in_broker_tests_aux,$1))
endef

define run_in_broker_tests_aux
	$(call run_broker,'-pa $(TEST_EBIN_DIR) -coverage directories ["$(EBIN_DIR)"$(COMMA)"$(TEST_EBIN_DIR)"]',,$(1)) &
	sleep 5
	echo > $(TEST_TMPDIR)/rabbit-test-output && \
	if $(foreach CMD,$(IN_BROKER_TEST_COMMANDS), \
	     echo >> $(TEST_TMPDIR)/rabbit-test-output && \
	     echo "$(CMD)." \
               | tee -a $(TEST_TMPDIR)/rabbit-test-output \
               | $(ERL_CALL) $(ERL_CALL_OPTS) \
               | tee -a $(TEST_TMPDIR)/rabbit-test-output \
               | egrep "{ok, " >/dev/null &&) \
	    $(foreach SCRIPT,$(IN_BROKER_TEST_SCRIPTS),$(SCRIPT) &&) : ; then \
	  echo "\nPASSED\n" ; \
	else \
	  cat $(TEST_TMPDIR)/rabbit-test-output ; \
	  echo "\n\nFAILED\n" ; \
	fi
	sleep 1
	echo "init:stop()." | $(ERL_CALL) $(ERL_CALL_OPTS)
	sleep 1
endef

# The targets common to all integrated packages
define package_targets

# Put all relevant ezs into the dist dir for this package, including
# the main ez file produced by this package
#
# When the package version changes, our .ez filename will change, and
# we need to regenerate the dist directory.  So the dependency needs
# to go via a stamp file that incorporates the version in its name.
# But we need a target with a fixed name for other packages to depend
# on.  And it can't be a phony, as a phony will always get rebuilt.
# Hence the need for two stamp files here.
$(PACKAGE_DIR)/dist/.done: $(PACKAGE_DIR)/dist/.done.$(PACKAGE_VERSION)
	touch $$@

$(PACKAGE_DIR)/dist/.done.$(PACKAGE_VERSION): $(PACKAGE_DIR)/build/dep-ezs/.done $(APP_DONE)
	rm -rf $$(@D)
	mkdir -p $$(@D)
	cd $(dir $(APP_DIR)) && zip -r $$(abspath $(EZ_FILE)) $(notdir $(APP_DIR))
	$$(call copy,$$(wildcard $$(<D)/*.ez),$(PACKAGE_DIR)/dist)
	touch $$@

# Gather all the ezs from dependency packages
$(PACKAGE_DIR)/build/dep-ezs/.done: $(foreach P,$(DEP_PATHS),$(P)/dist/.done)
	rm -rf $$(@D)
	mkdir -p $$(@D)
	$(if $(DEP_PATHS),$(foreach P,$(DEP_PATHS),$$(call copy,$$(wildcard $(P)/dist/*.ez),$$(@D),&&)) :)
	touch $$@

# Put together the main app tree for this package
$(APP_DONE): $(EBIN_BEAMS) $(INCLUDE_HRLS) $(APP_FILE) $(EXTRA_TARGETS)
	rm -rf $$(@D)
	mkdir -p $(APP_DIR)/ebin $(APP_DIR)/include
	$(call copy,$(EBIN_BEAMS),$(APP_DIR)/ebin)
	cp -a $(APP_FILE) $(APP_DIR)/ebin/$(APP_NAME).app
	$(call copy,$(INCLUDE_HRLS),$(APP_DIR)/include)
	$(call copy,$(EXTRA_PACKAGE_DIRS),$(APP_DIR))
	touch $$@

# Produce the .app file
$(APP_FILE): $(ORIGINAL_APP_FILE)
	@mkdir -p $$(@D)
	sed -e 's|{vsn, *\"[^\"]*\"|{vsn,\"$(PACKAGE_VERSION)\"|' <$$< >$$@

# Unpack the ezs from dependency packages, so that their contents are
# accessible to erlc
$(PACKAGE_DIR)/build/dep-apps/.done: $(PACKAGE_DIR)/build/dep-ezs/.done
	rm -rf $$(@D)
	mkdir -p $$(@D)
	cd $$(@D) && $$(foreach EZ,$$(wildcard $(PACKAGE_DIR)/build/dep-ezs/*.ez),unzip $$(abspath $$(EZ)) &&) :
	touch $$@

# Dependency autogeneration.  This is complicated slightly by the need
# to generate a dependency file which is path-independent.
$(DEPS_FILE): $(SOURCE_ERLS) $(INCLUDE_HRLS)
	@mkdir -p $$(@D)
	$$(if $$^,escript $(abspath $(UMBRELLA_BASE_DIR)/generate_deps) $$@ '$$$$(EBIN_DIR)' $$(foreach F,$$^,$$(abspath $$(F))),echo >$$@)
	sed -i -e 's|$$@|$$$$(DEPS_FILE)|' $$@

$(eval $(call safe_include,$(DEPS_FILE)))

$(PACKAGE_DIR)+clean::
	rm -rf $(EBIN_DIR)/*.beam $(TEST_EBIN_DIR)/*.beam $(PACKAGE_DIR)/dist $(PACKAGE_DIR)/build

$(PACKAGE_DIR)+clean-with-deps:: $(foreach P,$(DEP_PATHS),$(P)+clean-with-deps)

ifdef RELEASABLE
all-releasable:: $(PACKAGE_DIR)/dist/.done

copy-releasable:: $(PACKAGE_DIR)/dist/.done
	cp $(PACKAGE_DIR)/dist/*.ez $(PLUGINS_DIST_DIR)
endif

# Run erlang with the package, its tests, and all its dependencies
# available.
.PHONY: $(PACKAGE_DIR)+run
$(PACKAGE_DIR)+run: $(PACKAGE_DIR)/dist/.done $(TEST_EBIN_BEAMS)
	ERL_LIBS=$(PACKAGE_DIR)/dist $(ERL) -pa $(TEST_EBIN_DIR)

# Run the broker with the package, its tests, and all its dependencies
# available.
.PHONY: $(PACKAGE_DIR)+run-in-broker
$(PACKAGE_DIR)+run-in-broker: $(PACKAGE_DIR)/dist/.done $(RABBITMQ_SERVER_PATH)/dist/.done $(TEST_EBIN_BEAMS)
	$(call run_broker,'-pa $(TEST_EBIN_DIR)',RABBITMQ_ALLOW_INPUT=true)

# A hook to allow packages to verify that prerequisites are satisfied
# before running tests.
.PHONY: $(PACKAGE_DIR)+pre-test
$(PACKAGE_DIR)+pre-test::

# Runs the package's tests that operate within (or in conjuction with)
# a running broker.
.PHONY: $(PACKAGE_DIR)+in-broker-test
$(PACKAGE_DIR)+in-broker-test: $(PACKAGE_DIR)/dist/.done $(RABBITMQ_SERVER_PATH)/dist/.done $(TEST_EBIN_BEAMS) $(PACKAGE_DIR)+pre-test
	$(call run_in_broker_tests)

# Running the coverage tests requires Erlang/OTP R14. Note that
# coverage only covers the in-broker tests.
.PHONY: $(PACKAGE_DIR)+coverage
$(PACKAGE_DIR)+coverage: $(PACKAGE_DIR)/dist/.done $(COVERAGE_PATH)/dist/.done $(TEST_EBIN_BEAMS) $(PACKAGE_DIR)+pre-test
	$(call run_in_broker_tests,$(COVERAGE_PATH)/dist/*.ez)

# Runs the package's tests that don't need a running broker
.PHONY: $(PACKAGE_DIR)+standalone-test
$(PACKAGE_DIR)+standalone-test: $(PACKAGE_DIR)/dist/.done $(TEST_EBIN_BEAMS) $(PACKAGE_DIR)+pre-test
	$$(if $(STANDALONE_TEST_COMMANDS),\
	  $$(foreach CMD,$(STANDALONE_TEST_COMMANDS),\
	    ERL_LIBS=$(PACKAGE_DIR)/dist $(ERL) -pa $(TEST_EBIN_DIR) -eval "init:stop(case $$(CMD) of ok -> 0; _Else -> 1 end)" &&\
	  )\
	:)
	$$(if $(STANDALONE_TEST_SCRIPTS),$$(foreach SCRIPT,$(STANDALONE_TEST_SCRIPTS),$$(SCRIPT) &&) :)

# Run all the package's tests
.PHONY: $(PACKAGE_DIR)+test
$(PACKAGE_DIR)+test:: $(PACKAGE_DIR)+standalone-test $(PACKAGE_DIR)+in-broker-test

endef
$(eval $(package_targets))

# Recursing into dependency packages has to be the last thing we do
# because it will trample all over the per-package variables.

# Recurse into dependency packages
$(foreach DEP_PATH,$(DEP_PATHS),$(eval $(call do_package,$(DEP_PATH))))

else # NON_INTEGRATED_$(PACKAGE_DIR)

define package_targets

# When the package version changes, our .ez filename will change, and
# we need to regenerate the dist directory.  So the dependency needs
# to go via a stamp file that incorporates the version in its name.
# But we need a target with a fixed name for other packages to depend
# on.  And it can't be a phony, as a phony will always get rebuilt.
# Hence the need for two stamp files here.
$(PACKAGE_DIR)/dist/.done: $(PACKAGE_DIR)/dist/.done.$(VERSION)
	touch $$@

$(PACKAGE_DIR)/dist/.done.$(VERSION):
	rm -rf $$(@D)
	$$(MAKE) -C $(PACKAGE_DIR) VERSION=$(VERSION)
	mkdir -p $$(@D)
	touch $$@

$(PACKAGE_DIR)+clean::
	$$(MAKE) -C $(PACKAGE_DIR) clean
	rm -rf $(PACKAGE_DIR)/dist

endef
$(eval $(package_targets))

endif # NON_INTEGRATED_$(PACKAGE_DIR)
