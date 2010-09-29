.PHONY: $(PACKAGE_DIR)_OUTPUT_EZS
$(PACKAGE_DIR)_OUTPUT_EZS: $($(PACKAGE_DIR)_OUTPUT_EZS_PATHS)

.PHONY: run
run_DIST_DIR:=$(PACKAGE_DIR)/$(DIST_DIR)
run_TEST_EBIN_DIR:=$($(PACKAGE_DIR)_TEST_EBIN_DIR)
run: $($(PACKAGE_DIR)_TEST_EBIN_BEAMS) $(PACKAGE_DIR)_OUTPUT_EZS
	ERL_LIBS=$($@_DIST_DIR) $(ERL) -pa $($@_TEST_EBIN_DIR)

.PHONY: test
test_DIR:=$(PACKAGE_DIR)
test_TEST_EBIN_DIR:=$($(PACKAGE_DIR)_TEST_EBIN_DIR)
test: $($(PACKAGE_DIR)_TEST_EBIN_BEAMS)
	rm -rf $($@_DIR)/tmp $($@_DIR)/plugins $($@_DIR)/cover
	mkdir -p $($@_DIR)/tmp $($@_DIR)/plugins
	cp -a $($@_DIR)/$(DIST_DIR)/*.ez $($@_DIR)/plugins
	rm -f $($@_DIR)/plugins/rabbit_common*
	RABBITMQ_PLUGINS_DIR=$($@_DIR)/plugins RABBITMQ_NODENAME=$(NODENAME) \
	  RABBITMQ_LOG_BASE=$($@_DIR)/tmp RABBITMQ_MNESIA_BASE=$($@_DIR)/tmp \
	  RABBITMQ_SERVER_START_ARGS="-pa $($($@_DIR)_TEST_EBIN_DIR) -coverage directories [$($@_COVERAGE)]" \
	  $($@_DIR)/../rabbitmq-server/scripts/rabbitmq-server & sleep 8
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

.PHONY: clean_local
clean_local: $(PACKAGE_DIR)/clean
