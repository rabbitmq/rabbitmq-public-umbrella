.PHONY: $(PACKAGE_DIR)_OUTPUT_EZS
$(PACKAGE_DIR)_OUTPUT_EZS: $($(PACKAGE_DIR)_OUTPUT_EZS_PATHS)

ifeq "$(.DEFAULT_GOAL)" "$(PACKAGE_DIR)_OUTPUT_EZS_PATHS"
.DEFAULT_GOAL:=$($(.DEFAULT_GOAL))
endif

ifdef $(PACKAGE_DIR)_RELEASABLE
release: $($(PACKAGE_DIR)_OUTPUT_EZS_PATHS)
endif

.PHONY: run
run_DIST_DIR:=$(PACKAGE_DIR)/$(DIST_DIR)
run_TEST_EBIN_DIR:=$($(PACKAGE_DIR)_TEST_EBIN_DIR)
run: $($(PACKAGE_DIR)_TEST_EBIN_BEAMS) $(PACKAGE_DIR)_OUTPUT_EZS
	ERL_LIBS=$($@_DIST_DIR) $(ERL) -pa $($@_TEST_EBIN_DIR)

# $(1) is $(PACKAGE_DIR)
# $(2) is extra SERVER_START_ARGS
# $(3) is extra RABBITMQ_* env vars
define prepare_and_boot_broker
	rm -rf $(1)/tmp $(1)/plugins $(1)/cover
	mkdir -p $(1)/tmp $(1)/plugins
	cp -a $(1)/$(DIST_DIR)/*.ez $(1)/plugins
	rm -f $(1)/plugins/rabbit_common*
	RABBITMQ_PLUGINS_DIR=$(1)/plugins RABBITMQ_NODENAME=$(NODENAME) \
	  RABBITMQ_LOG_BASE=$(1)/tmp RABBITMQ_MNESIA_BASE=$(1)/tmp \
	  RABBITMQ_SERVER_START_ARGS="-pa $($(1)_TEST_EBIN_DIR) $(2)" \
	  $(3) $($@_DIR)/../rabbitmq-server/scripts/rabbitmq-server
endef

.PHONY: run_in_broker
run_in_broker_DIR:=$(PACKAGE_DIR)
run_in_broker: $($(PACKAGE_DIR)_TEST_EBIN_BEAMS) $(PACKAGE_DIR)_OUTPUT_EZS
	$(call prepare_and_boot_broker,$($@_DIR),,RABBITMQ_ALLOW_INPUT=true)

ifneq "$($(PACKAGE_DIR)_TEST_SCRIPTS)$($(PACKAGE_DIR)_TEST_COMMANDS)" ""
.PHONY: test
test_DIR:=$(PACKAGE_DIR)
test_TEST_EBIN_DIR:=$($(PACKAGE_DIR)_TEST_EBIN_DIR)
test: $($(PACKAGE_DIR)_TEST_EBIN_BEAMS)
	$(call prepare_and_boot_broker,$($@_DIR),-coverage directories [$($@_COVERAGE)],) &
	sleep 8
	@echo > $($@_DIR)/rabbit-test-output && \
	{ $(foreach BOOT_CMD,$(BOOT_CMDS),\
            echo "$(BOOT_CMD)." | tee -a $($@_DIR)/rabbit-test-output | $(ERL_CALL) $(ERL_CALL_OPTS) | tee -a $($@_DIR)/rabbit-test-output | egrep "{ok, " >/dev/null && ) true && \
	  $(foreach CMD,$($($@_DIR)_TEST_COMMANDS), \
	    echo >> $($@_DIR)/rabbit-test-output && \
	    echo "$(CMD)." | tee -a $($@_DIR)/rabbit-test-output | $(ERL_CALL) $(ERL_CALL_OPTS) | tee -a $($@_DIR)/rabbit-test-output | egrep "{ok, " >/dev/null && ) true && \
	  $(foreach SCRIPT,$($($@_DIR)_TEST_SCRIPTS),$(SCRIPT) && ) true || OK=false; } && \
	{ $$OK || { cat $($@_DIR)/rabbit-test-output; echo "\n\nFAILED\n"; }; } && \
	$(foreach CLEANUP_CMD,$(CLEANUP_CMDS),\
            echo "$(CLEANUP_CMD)." | tee -a $($@_DIR)/rabbit-test-output | $(ERL_CALL) $(ERL_CALL_OPTS) | tee -a $($@_DIR)/rabbit-test-output | egrep "{ok, " >/dev/null; ) true && \
	sleep 1 && \
	echo "init:stop()." | $(ERL_CALL) $(ERL_CALL_OPTS) && \
	rm -rf $($@_DIR)/tmp $($@_DIR)/plugins && \
	{ $$OK && echo "\nPASSED\n"; }

ifneq "$(findstring coverage,$(TESTABLEGOALS))" ""
DEPS += coverage
test_COVERAGE:=$(subst "\"" "\"","\""$(COMMA)"\"",$(foreach DIR,$(test_TEST_EBIN_DIR) $($(PACKAGE_DIR)_EBIN_DIR),"\""$(DIR)"\""))
endif

.PHONY: coverage
coverage: test
endif # ifneq "$($(PACKAGE_DIR)_TEST_SCRIPTS)$($(PACKAGE_DIR)_TEST_COMMANDS)" ""

.PHONY: clean_local
clean_local: $(PACKAGE_DIR)/clean
