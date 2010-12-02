# The default goal
all:

UMBRELLA_BASE_DIR:=..

include $(UMBRELLA_BASE_DIR)/common.mk

# We start at the initial package (i.e. the one in the current directory)
PACKAGE_DIR:=$(call canonical_path,.)

# Produce all of the releasable artifacts of this package
all: $(PACKAGE_DIR)+all

# Clean the package and all its dependencies
clean: $(PACKAGE_DIR)+clean-with-deps

# Clean just the initial package
clean-local: $(PACKAGE_DIR)+clean

# Do the initial package
include $(UMBRELLA_BASE_DIR)/do-package.mk

# We always need the coverage package to support the coverage goal
PACKAGE_DIR:=$(COVERAGE_PATH)
$(eval $(call do_package,$(COVERAGE_PATH)))
