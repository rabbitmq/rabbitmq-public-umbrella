# Introduction
# ============
#
# If you're a plugin developer and want to get your plugin to work
# with the build system, please see the README.makefiles file.
#
#
# Internal notes
# ==============
#
# This diagram reflects only the general theme of the dependencies and
# does not cover tests or the various extension points for additional
# targets.
#
#      ebin/$(APP_NAME).app -?-> ebin/$(APP_NAME)_app.in
#       ^
#       |
# --> $(DIST_DIR)/$(OUTPUT_EZS) -|-> $(DIST_DIR)
#       |
#       +------------------------------------\
#       |                                     V
#       |            /--> deps.mk --\   /--> include/*.hrl
#       V            |               }-{
#      ebin/*.beam --+--------------/   \--> src/*.erl
#                    |
#                    \--> $(DIST_DIR)/$(OUTPUT_EZS).stamp
#                           |
#                           V
#                          $(DEPS)/$(DIST_DIR)/$(OUTPUT_EZS) [RECURSE] -->
#
# Notes
#
# 1. The contents of deps.mk itself expresses the dependencies between
# the beams and erls/hrls.
#
# 2. If package foo depends on bar, and package bar depends on baz,
# then when compiling foo, the .ezs from _both_ bar and baz must be
# present in foo. I.e. the transitive closure of OUTPUT_EZS is
# required as we move up the dependency chain. This is not represented
# in the above diagram.
#
# 3. The contents of global.mk are included just once.
#
# 4. common.mk is included every time we visit a package. This is true
# even if we've already visited a package and is essential as we may
# discover a package has more parents than we'd previously thought and
# the dependencies for OUTPUT_EZS needs correcting (see point 2
# above). E.g. foo -> bar; foo -> baz; bar -> qux; baz -> qux: when
# visiting qux, we need to ensure both bar and baz depend on the
# qux.ez outputs. However, in subsequent visits to qux, we detect
# whether we've already loaded that package, and minimise the work we
# have to do.
#
# 5. targets.mk is only included for fully integrated packages and is
# only included once per package.
#
# 6. non-integrated.mk is included only for non-integrated packages
# (currently erlang-client and server) and is only included once per
# such package.
#
# 7. For general debugging and understanding, try changing $(eval ...)
# calls to $(info ...) calls and then it'll break, but print out what
# Makefile fragments have been generated and were to be interpreted.
#
# 8. Support for non integrated packages errs on the safe-side: the
# output EZs of such packages are declared PHONY. As a result,
# whenever such a package is a prerequisite, all subsequent steps will
# always be taken. However, make -j still works, and there is no
# possibility of missing changes.
#
#
# The purpose of this file is to load the global definitions and then
# start on the recursive descent of the package dependencies by
# including deps.mk.

include ../global.mk
include ../deps.mk
