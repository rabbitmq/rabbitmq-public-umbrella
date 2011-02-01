# The default goal
all:

UMBRELLA_BASE_DIR:=..

include $(UMBRELLA_BASE_DIR)/common.mk

# We start at the initial package (i.e. the one in the current directory)
PACKAGE_DIR:=$(call canonical_path,.)

# Produce all of the releasable artifacts of this package
.PHONY: all
all: $(PACKAGE_DIR)+all

# Clean the package and all its dependencies
.PHONY: clean
clean: $(PACKAGE_DIR)+clean-with-deps

# Clean just the initial package
.PHONY: clean-local
clean-local: $(PACKAGE_DIR)+clean

# Runs the package's tests
.PHONY: test
test: $(PACKAGE_DIR)+test

# Test the package with code coverage recording on.  Note that
# coverage only covers the in-broker tests.
.PHONY: coverage
coverage: $(PACKAGE_DIR)+coverage

# Do the initial package
include $(UMBRELLA_BASE_DIR)/do-package.mk

# We always need the coverage package to support the coverage goal
PACKAGE_DIR:=$(COVERAGE_PATH)
$(eval $(call do_package,$(COVERAGE_PATH)))
