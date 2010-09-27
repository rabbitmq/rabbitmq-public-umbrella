ifdef PACKAGE_DIR
ifndef $(PACKAGE_DIR)_TARGETS
$(PACKAGE_DIR)_TARGETS:=true

# get the ezs to depend on the beams, hrls and $(DIST_DIR)
$(foreach EZ,$($(PACKAGE_DIR)_OUTPUT_EZS),$(eval $(PACKAGE_DIR)/$(DIST_DIR)/$(EZ)-$($(PACKAGE_DIR)_VERSION).ez: $($(PACKAGE_DIR)_EBIN_BEAMS) $($(PACKAGE_DIR)_INCLUDE_HRLS)))

# get extra targets to depend on the beams, hrls and $(DIST_DIR)
$(foreach TARGET,$($(PACKAGE_DIR)_EXTRA_TARGETS),$(eval $(TARGET): $($(PACKAGE_DIR)_EBIN_BEAMS) $($(PACKAGE_DIR)_INCLUDE_HRLS)))

# note don't use $^ in the escript line because it'll include prereqs that we add elsewhere
$($(PACKAGE_DIR)_DEPS_FILE)_EBIN_DIR:=$($(PACKAGE_DIR)_EBIN_DIR)
$($(PACKAGE_DIR)_DEPS_FILE): $($(PACKAGE_DIR)_SOURCE_ERLS) $($(PACKAGE_DIR)_INCLUDE_HRLS)
	rm -f $@
	escript $(@D)/../generate_deps $@ $($(@D)_EBIN_DIR) $($(@D)_SOURCE_ERLS) $($(@D)_INCLUDE_HRLS)

# make our beams depend on the existence of the deps file only
$($(PACKAGE_DIR)_EBIN_BEAMS): | $($(PACKAGE_DIR)_DEPS_FILE)

$($(PACKAGE_DIR)_EBIN_DIR)_INCLUDE_DIR:=$($(PACKAGE_DIR)_INCLUDE_DIR)
$($(PACKAGE_DIR)_EBIN_DIR)_DIST_DIR:=$(PACKAGE_DIR)/$(DIST_DIR)
$($(PACKAGE_DIR)_EBIN_DIR)_OPTS:=$($(PACKAGE_DIR)_ERLC_OPTS) $(GLOBAL_ERLC_OPTS)
$($(PACKAGE_DIR)_EBIN_DIR)/%.beam: $($(PACKAGE_DIR)_SOURCE_DIR)/%.erl | $($(PACKAGE_DIR)_EBIN_DIR) $(PACKAGE_DIR)/$(DIST_DIR) $(PACKAGE_DIR)/$(DEPS_DIR)
	ERL_LIBS=$($(@D)_DIST_DIR) $(ERLC) $($(@D)_OPTS) -I $($(@D)_INCLUDE_DIR) -pa $(@D) -o $(@D) $<

$($(PACKAGE_DIR)_EBIN_DIR):
	mkdir -p $@

$($(PACKAGE_DIR)_TEST_EBIN_DIR)_MAIN_EBIN_DIR:=$($(PACKAGE_DIR)_EBIN_DIR)
$($(PACKAGE_DIR)_TEST_EBIN_DIR)_INCLUDE_DIR:=$($(PACKAGE_DIR)_INCLUDE_DIR)
$($(PACKAGE_DIR)_TEST_EBIN_DIR)_DIST_DIR:=$(PACKAGE_DIR)/$(DIST_DIR)
$($(PACKAGE_DIR)_TEST_EBIN_DIR)_OPTS:=$($(PACKAGE_DIR)_ERLC_OPTS) $(GLOBAL_ERLC_OPTS)
$($(PACKAGE_DIR)_TEST_EBIN_DIR)/%.beam: $($(PACKAGE_DIR)_TEST_SOURCE_DIR)/%.erl | $($(PACKAGE_DIR)_TEST_EBIN_DIR) $(PACKAGE_DIR)/$(DIST_DIR) $(PACKAGE_DIR)/$(DEPS_DIR)
	ERL_LIBS=$($(@D)_DIST_DIR) $(ERLC) $($(@D)_OPTS) -I $($(@D)_INCLUDE_DIR) -pa $(@D) -pa $($(@D)_MAIN_EBIN_DIR) -o $(@D) $<

$($(PACKAGE_DIR)_TEST_EBIN_DIR):
	mkdir -p $@

# only do the _app.in => .app dance if we can actually find a
# _app.in. If we can, make it phony because otherwise it may not be
# rebuilt if just the version changes.
ifneq "$(wildcard $($(PACKAGE_DIR)_EBIN_DIR)/$($(PACKAGE_DIR)_APP_NAME)_app.in)" ""
.PHONY: $($(PACKAGE_DIR)_EBIN_DIR)/$($(PACKAGE_DIR)_APP_NAME).app
$($(PACKAGE_DIR)_EBIN_DIR)/$($(PACKAGE_DIR)_APP_NAME).app_VERSION:=$($(PACKAGE_DIR)_VERSION)
$($(PACKAGE_DIR)_EBIN_DIR)/$($(PACKAGE_DIR)_APP_NAME).app: $($(PACKAGE_DIR)_EBIN_DIR)/$($(PACKAGE_DIR)_APP_NAME)_app.in
	sed -e 's:%%VSN%%:$($@_VERSION):g' < $< > $@

.PHONY: $(PACKAGE_DIR)/clean_app
$(PACKAGE_DIR)/clean:: $(PACKAGE_DIR)/clean_app
$(PACKAGE_DIR)/clean_app:
	rm -f $($(@D)_EBIN_DIR)/$($(@D)_APP_NAME).app
endif

.PHONY: $(PACKAGE_DIR)/clean
clean:: $(PACKAGE_DIR)/clean
$(PACKAGE_DIR)/clean::
	rm -f $($(@D)_DEPS_FILE)
	rm -rf $(@D)/$(DIST_DIR)
	rm -f $($(@D)_EBIN_BEAMS) $($(@D)_GENERATED_ERLS) $($(@D)_TEST_EBIN_BEAMS)

ifndef CLEAN_LOCAL
CLEAN_LOCAL:=true
.PHONY: clean_local
clean_local: $(PACKAGE_DIR)/clean
endif

# only set up a target for the plain package ez. Other ezs must be
# handled manually. .beam dependencies et al are created by the
# generic output_ezs dependencies. For ease of comprehension, we save
# out variables that we need.
$(PACKAGE_DIR)/$(DIST_DIR)/$($(PACKAGE_DIR)_APP_NAME)-$($(PACKAGE_DIR)_VERSION).ez_DIR:=$(PACKAGE_DIR)/$(DIST_DIR)/$($(PACKAGE_DIR)_APP_NAME)-$($(PACKAGE_DIR)_VERSION)
$(PACKAGE_DIR)/$(DIST_DIR)/$($(PACKAGE_DIR)_APP_NAME)-$($(PACKAGE_DIR)_VERSION).ez_APP:=$($(PACKAGE_DIR)_EBIN_DIR)/$($(PACKAGE_DIR)_APP_NAME).app
$(PACKAGE_DIR)/$(DIST_DIR)/$($(PACKAGE_DIR)_APP_NAME)-$($(PACKAGE_DIR)_VERSION).ez_EBIN_BEAMS:=$($(PACKAGE_DIR)_EBIN_BEAMS)
$(PACKAGE_DIR)/$(DIST_DIR)/$($(PACKAGE_DIR)_APP_NAME)-$($(PACKAGE_DIR)_VERSION).ez_INCLUDE_HRLS:=$($(PACKAGE_DIR)_INCLUDE_HRLS)
$(PACKAGE_DIR)/$(DIST_DIR)/$($(PACKAGE_DIR)_APP_NAME)-$($(PACKAGE_DIR)_VERSION).ez_EXTRA_PACKAGE_DIRS:=$($(PACKAGE_DIR)_EXTRA_PACKAGE_DIRS)
$(PACKAGE_DIR)/$(DIST_DIR)/$($(PACKAGE_DIR)_APP_NAME)-$($(PACKAGE_DIR)_VERSION).ez: $($(PACKAGE_DIR)_EBIN_DIR)/$($(PACKAGE_DIR)_APP_NAME).app $($(PACKAGE_DIR)_EXTRA_TARGETS) | $(PACKAGE_DIR)/$(DIST_DIR) $($(PACKAGE_DIR)_EXTRA_PACKAGE_DIRS)
	rm -rf $@ $($@_DIR)
	mkdir -p $($@_DIR)/ebin $($@_DIR)/include
	$(foreach BEAM,$($@_EBIN_BEAMS),cp $(BEAM) $($@_DIR)/ebin;)
	$(foreach HRL,$($@_INCLUDE_HRLS),cp $(HRL) $($@_DIR)/include;)
	$(foreach EXTRA_DIR,$($@_EXTRA_PACKAGE_DIRS),cp -r $(EXTRA_DIR) $($@_DIR);)
	cp $($@_APP) $($@_DIR)/ebin
	cd $(dir $($@_DIR)) && zip -r $@ $(notdir $(basename $@))

$(PACKAGE_DIR)/$(DIST_DIR)/$($(PACKAGE_DIR)_APP_NAME)_TARGET:=true

define generic_ez
# $(EZ) is in $(1)
ifndef $(PACKAGE_DIR)/$(DIST_DIR)/$(1)_TARGET
$(PACKAGE_DIR)/$(DIST_DIR)/$(1)_TARGET:=true
.PHONY: $(PACKAGE_DIR)/$(DIST_DIR)/$(1)-$($(PACKAGE_DIR)_VERSION).ez
$(PACKAGE_DIR)/$(DIST_DIR)/$(1)-$($(PACKAGE_DIR)_VERSION).ez:
	$(MAKE) -C $(PACKAGE_DIR)/$(DEPS_DIR)/$(1) -j
	cp $(PACKAGE_DIR)/$(DEPS_DIR)/$(1)/$$(@F) $$@
	rm -rf $$(basename $$@)
	cd $$(@D) && unzip $$(@F)

$(PACKAGE_DIR)/clean::
	$(MAKE) -C $(PACKAGE_DIR)/$(DEPS_DIR)/$(1) clean
endif
endef

$(foreach EZ,$($(PACKAGE_DIR)_OUTPUT_EZS) $($(PACKAGE_DIR)_INTERNAL_DEPS),$(eval $(call generic_ez,$(strip $(EZ)))))

$($(PACKAGE_DIR)_EBIN_BEAMS): $(patsubst %,$(PACKAGE_DIR)/$(DIST_DIR)/%-$($(PACKAGE_DIR)_VERSION).ez,$($(PACKAGE_DIR)_INTERNAL_DEPS))

ifneq "$(strip $(TESTABLEGOALS))" "$($(PACKAGE_DIR)_DEPS_FILE)"
ifneq "$(strip $(patsubst clean%,,$(patsubst %clean,,$(TESTABLEGOALS))))" ""
-include $($(PACKAGE_DIR)_DEPS_FILE)
endif
endif

endif
endif
