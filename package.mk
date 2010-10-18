# The purpose of this file is to set and lift all package-specific
# variables into the package's namespace. Thus it does not set up any
# dependencies, and merely includes other files as necessary. The last
# thing it does is to include deps.mk, which causes recursive descent
# of the package's dependencies.
#
#
# First blank out all the variables.
$(foreach VAR,$(VARS),$(eval $(VAR):=))

# Now define the variables to their defaults, but use recursive
# assignment (=), not simple assignment, so that if the package's
# package.mk changes any variables, dependent variables will get
# recalculated automatically.
SOURCE_DIR=$(PACKAGE_DIR)/src
SOURCE_ERLS=$(wildcard $(SOURCE_DIR)/*.erl)

INCLUDE_DIR=$(PACKAGE_DIR)/include
INCLUDE_HRLS=$(wildcard $(INCLUDE_DIR)/*.hrl)

EBIN_DIR=$(PACKAGE_DIR)/ebin
EBIN_BEAMS=$(patsubst $(SOURCE_DIR)/%.erl,$(EBIN_DIR)/%.beam,$(SOURCE_ERLS))

APP_NAME=$(call package_to_app_name,$(PACKAGE_NAME))
OUTPUT_EZS=$(APP_NAME)
DEPS_FILE=$(PACKAGE_DIR)/deps.mk
VERSION=$(GLOBAL_VERSION)
OUTPUT_EZS_PATHS=$(patsubst %,$(PACKAGE_DIR)/$(DIST_DIR)/%-$(VERSION).ez,$(OUTPUT_EZS))
INTERNAL_DEPS_PATHS=$(patsubst %,$(PACKAGE_DIR)/$(DIST_DIR)/%-$(VERSION).ez,$(INTERNAL_DEPS))

TEST_DIR=$(PACKAGE_DIR)/test
TEST_SOURCE_DIR=$(TEST_DIR)/src
TEST_SOURCE_ERLS=$(wildcard $(TEST_SOURCE_DIR)/*.erl)
TEST_EBIN_DIR=$(TEST_DIR)/ebin
TEST_EBIN_BEAMS=$(patsubst $(TEST_SOURCE_DIR)/%.erl,$(TEST_EBIN_DIR)/%.beam,$(TEST_SOURCE_ERLS))

# With default values assigned, now include the package's package.mk
include $(PACKAGE_DIR)/package.mk

# Now lift (which will use simple assignment (:=)) all the variables
# to the package's namespace to protect them from further accidental
# modification.
$(foreach VAR,$(VARS),$(eval $(call lift_var,$(VAR),$(PACKAGE_DIR))))

$(PACKAGE_DIR)_SOURCE_ERLS += $($(PACKAGE_DIR)_GENERATED_ERLS)

ifdef DUMP_VARS
$(foreach VAR,$(VARS),$(info $(call dump_var,$(VAR))))
endif

ifndef TOP_LEVEL
TOP_LEVEL:=true
include ../top.mk
endif

# include common so that our parents depend on our OUTPUT_EZS
include ../common.mk

# recurse into our own dependencies
include ../deps.mk
