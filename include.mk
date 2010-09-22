# Introduction
# ============
#
# This suite of Makefiles exists to make it easy to express dependency
# relationships between different plugins (or packages - from here on
# called the package as not all packages have to be plugins), and to
# have them build easily. The general idea is that in your package
# directory you have a Makefile, in which you first declare a few
# variables, and then the last thing is you "include
# ../include.mk". You should then be able to issue make within your
# package directory and rely on this system to build all the
# dependencies required.
#
# The overall goal is the construction of a .ez file, with the name
# based on the package name. This will be constructed and placed in
# the dist directory. In that directory you will also find the out of
# of the transitive closure of all dependencies of the
# package. E.g. if your package is A, and depends on B, and package B
# depends on C, then C will produce C.ez which will be supplied to
# B. B will produce B.ez and then both C.ez and B.ez will be supplied
# to A, which will produce A.ez, leaving all three .ez files in the
# dist directory of C.
#
# Recursive invocations of make are avoided where ever and are
# undesirable. This is because they must be declared as .PHONY targets
# (because they themselves are encapsulating the dependency
# information required to determine whether or not anything needs
# rebuilding) and thus are always re-invoked. The properties of .PHONY
# targets are that anything that depends on a .PHONY target is itself
# a .PHONY target. This is unfortunate as it means that any package
# that depends on any other package that is not fully integrated with
# this system, and thus requires recursive make, is itself forever
# rebuilt. Hopefully the existence of this system will slowly force
# other important packages to become properly integrated: the
# rabbitmq-erlang-client and rabbitmq-server being the primary
# sticking points. Nevertheless, the correct tracking of dependencies
# between packages means you never have to explicitly rebuild in some
# other package directory, and you never need to issue make clean to
# get rid of out-of-date artifacts.
#
#
# Package Makefile
# ================
#
# The package Makefile should not assume it is the top-level
# Makefile. It should never refer to paths relative to itself. This is
# because some other package could always depend upon it and thus
# paths would be relative to that other directory.
#
# To aid with this, before a package Makefile is read, the variables
# PACKAGE_DIR and PACKAGE_NAME are set. The former is the absolute
# path to and including the package directory, whilst the latter is
# just the name of the package directory. These variables should never
# be modified. (In the case of the top-level Makefile, it is actually
# read twice: the second time with these variables set).
#
# The general structure of the Makefile should be to set the variables
# and rules it needs, and then to call "include ../include.mk". Note
# that the include must be the last thing to happen because once
# control flow returns beneath this point, the values of PACKAGE_DIR
# and PACKAGE_NAME may well have changed, thus it is not safe to use
# them. (At this point, it's actually returning up the chain of
# dependencies: PACKAGE_NAME and PACKAGE_DIR will likely represent one
# of the leaves in the dependency tree.)
#
#
# Variables
# ---------
#
# Don't ever assign to these:
#
# PACKAGE_NAME :: string - name of package directory
# PACKAGE_DIR :: abspath - absolute path to and including package dir
#
# The following can be changed, but only globally, not per package
# (i.e. set them as environment variables or arguments to the top
# level make invocation). Note they may be lost for non-integrated
# packages.
#
# ERLC :: string - defaults to erlc
# ERLC_OPTS :: string defaults to "-Wall +debug_info"
# ERL :: string - defaults to erl
# TMPDIR :: path - defaults to /tmp
# DIST_DIR :: path - defaults to dist
# DEPS_DIR :: path - defaults to deps
#
# The following are the variables that may be set in the package
# Makefile. In general, unless you know better, please use := to
# declare these variables, not =
#
# SOURCE_DIR :: abspath
#   Default: $(PACKAGE_DIR)/src
#
# SOURCE_ERLS :: [abspath]
#   Default: $(wildcard $(SOURCE_DIR)/*.erl)
#   Notes: Be careful with the effect of this, GENERATED_ERLS, and the
#   potential for infinite recursion. See Note on Dynamic Dependencies
#   below.
#
# INCLUDE_DIR :: abspath
#   Default: $(PACKAGE_DIR)/include
#
# INCLUDE_HRLS :: [abspath]
#   Default: $(wildcard $(INCLUDE_DIR)/*.hrl)
#
# EBIN_DIR :: abspath
#   Default: $(PACKAGE_DIR)/ebin
#
# EBIN_BEAMS :: [abspath]
#   Default: $(patsubst $(SOURCE_DIR)/%.erl,$(EBIN_DIR)/%.beam,$(SOURCE_ERLS))
#
# These first six variables set up the basic means for constructing
# the contents of the $(PACKAGE_NAME).ez default output target. The
# source erls must be compiled to beams and then with the hrls, placed
# in the $(PACKAGE_NAME).ez. Note that our "generate_deps" script is
# used to dynamically find the dependencies between the hrls, erls and
# beams.
#
# DEPS :: [string]
#   Default:
#   Notes: name the packages that you depend on (names only - not
#   paths). These should correspond to directory names that are
#   siblings of the current package. Name the package, not the
#   artifacts produced by building that package.
#
# The following variables you should only have to touch if you're
# doing something a bit special:
#
# GENERATED_ERLS :: [abspath]
#   Default:
#   Notes: If you are dynamically generating sources, set this to the
#   absolute paths of the sources you are generating. You will likely
#   have to add explicit rules to your Makefile to ensure these
#   sources can be built. Note that the $(DEPS_FILE) depends on these
#   sources (the sources must exist before dependency analysis can
#   occur) and there is the potential for infinite recursion with this
#   feature in combination with $(SOURCE_ERLS). See Note on Dynamic
#   Dependencies below.
#
# APP_NAME :: string
#   Default: $(PACKAGE_NAME) with _ for - and with rabbit for rabbitmq
#   Notes: This determines the expected name of the app descriptor. As
#   part of building $(PACKAGE_NAME).ez, it is expected to find
#   $(EBIN_DIR)/$(APP_NAME).app. Iff $(EBIN_DIR)/$(APP_NAME)_app.in is
#   found, $(EBIN_DIR)/$(APP_NAME).app will be automatically generated
#   from this, replacing %%VSN%% with $(VERSION) in the file content.
#
# OUTPUT_EZS :: [string ending with .ez]
#   Default: $(PACKAGE_NAME).ez
#   Notes: This forms the top level goals for each package. Every
#   string in this variable (EZ) will result in an attempt to build
#   $(PACKAGE_DIR)/$(DIST_DIR)/$(EZ). Every EZ depends on all the
#   $(EBIN_BEAMS) being built. By default, $(PACKAGE_NAME).ez will
#   construct, as previously described, a .ez containing the
#   $(EBIN_BEAMS) and $(EBIN_HRLS) configured. Other EZs within
#   $(OUTPUT_EZS) which are not $(PACKAGE_NAME).ez will default to a
#   recursive make invocation in
#   $(PACKAGE_DIR)/$(DEPS_DIR)/$(basename $(EZ)) with the assumption
#   that this will cause
#   $(PACKAGE_DIR)/$(DEPS_DIR)/$(basename $(EZ))/$(EZ) to be
#   constructed, which will then be copied to
#   $(PACKAGE_DIR)/$(DIST_DIR). However, in general, recursive make is
#   evil and as explained above must always be .PHONY.
#
# INTERNAL_DEPS :: [string ending with .ez]
#   Default:
#   See also: EXTRA_TARGETS
#   Notes: This operates identically to OUTPUT_EZS with the exception
#   that $(EBIN_BEAMS) depends on these targets. I.e. if you need some
#   libraries to be compiled before your own $(SOURCE_ERLS) can be
#   compiled then you need to have those libraries compiled and placed
#   into a .ez by the same mechanism as described in OUTPUT_EZS above.
#
# Important note for OUTPUT_EZS and INTERNAL_DEPS
#   You may want the default recipe of the recursive make invocation
#   in $(PACKAGE_DIR)/$(DEPS_DIR)/$(basename $(EZ)) - you may wish to
#   provide your own recipe. In that case, set
#   $(PACKAGE_DIR)/$(DIST_DIR)/$(EZ)_TARGET and then provide a rule to
#   build $(PACKAGE_DIR)/$(DIST_DIR)/$(EZ). E.g. if you want to
#   manually control the building of foo.ez, in the package Makefile:
#
#   $(PACKAGE_DIR)/$(DIST_DIR)/foo.ez:=true
#   $(PACKAGE_DIR)/$(DIST_DIR)/foo.ez: ... foo's prerequisites ...
#            ... instructions to build foo.ez ...
#            cd $(@D) && unzip $@
#
#   Note the last instruction is required due to limitations of erlc:
#   the EZ must be unpacked in the $(DIST_DIR). Also DO NOT use
#   $(PACKAGE_DIR) in recipe _commands_ as variables in recipes are
#   only expanded when the recipe is invoked. At this point, the value
#   of $(PACKAGE_DIR) may well refer to some other package. $(@D) and
#   friends are the correct solution to this problem.
#
# EXTRA_PACKAGE_DIRS :: [abspath]
#   Default:
#   Notes: These are paths to directories that you want to be included
#   in $(PACKAGE_NAME).ez. The $(PACKAGE_NAME).ez target has an
#   order-only prerequisite on $(EXTRA_PACKAGE_DIRS) (i.e. they must
#   exist, but timestamps are ignored). No targets are provided to
#   build these directories so if they don't already exist, you should
#   arrange for them to be created. Something like:
#
#   $(EXTRA_PACKAGE_DIRS): %:
#           mkdir -p $@
#
#   would work well (static pattern rule).
#
# EXTRA_TARGETS :: [string]
#   Default:
#
#   Notes: The targets listed here depend on the $(EBIN_BEAMS) being
#   built and are prerequisites of $(PACKAGE_NAME).ez. Thus like
#   OUTPUT_EZS, these will be invoked only after the $(EBIN_BEAMS)
#   have been built, but there are no default recipes. One example use
#   of this is to ensure other package artifacts are built.
#
# The following variables you should never have to touch.
#
# DEPS_FILE :: abspath
#   Default: $(PACKAGE_DIR)/deps.mk
#   Notes: This is the location of the file created by the
#   generate_deps script. There is no reason to change this from its
#   default.
#
#
# Important Note on Dynamic Dependencies
# --------------------------------------
#
# There is a potential problem with non-integrated dependencies
# (recursive invocations of make), and generated sources that can lead
# to infinite recursion.
#
# Example:
#
# DEPS:=something-non-integrated
# GENERATE_SOURCES:=$(PACKAGE_DIR)/src/foo.erl
#
# %/src/foo.erl: %/src/foo.input %/ebin/library.beam
#         $(ERL) -pa ebin -noshell -eval 'library:do_work("$@", "$<")'
#
# Thus to build deps.mk, we need to generate foo.erl. This requires
# compiling library.erl into library.beam. Once this has happened, we
# can create deps.mk and then make will re-invoke itself. However, we
# also have that all the beams have the various DEPS as prerequisites.
# Thus we can start by going off and building the DEPS. Then we can
# build library.beam from library.erl, and then foo.erl as per the
# rule above. Then we can do dependency analysis and spit out our
# deps.mk DEPS_FILE which we then try and include. Thus make includes
# the DEPS_FILE and starts again. However, because the DEPS are
# non-integrated and thus .PHONY, it has no choice but to run them
# again. Even if the DEP doesn't produce new artifacts, by the very
# fact it's .PHONY, its artifacts, fresh or not, get copied and
# unpacked in our DIST_DIR. They are now found to be younger than
# library.beam. As a result library.beam has to be remade, which then
# means that foo.erl has to be remade which then means that the
# DEPS_FILE has to be remade... cue loop.
#
# The problem here is that library.erl is in SOURCE_ERLS, and
# subsequently ends up in EBIN_BEAMS, hence depends on DEPS. If we
# avoid that, then whilst foo.beam may need to be rebuilt owing to
# updated DEPS artifacts, we do not need to rebuild foo.erl, and thus
# the DEPS_FILE doesn't become invalidated. Thus the solution is:
#
# SOURCE_DIR:=$(PACKAGE_DIR)/src
# SOURCE_ERLS:=$(filter-out %/library.erl,$(wildcard $(SOURCE_DIR)/*.erl))
#
#
# Internal notes
# ==============
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
# qux.ez outputs.
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

include ../global.mk

VARS:=SOURCE_DIR SOURCE_ERLS INCLUDE_DIR INCLUDE_HRLS EBIN_DIR EBIN_BEAMS DEPS_FILE APP_NAME OUTPUT_EZS INTERNAL_DEPS EXTRA_PACKAGE_DIRS EXTRA_TARGETS GENERATED_ERLS

ifdef PACKAGE_DIR

define default_and_lift_var
ifeq ($(origin $(1)), undefined)
$(PACKAGE_DIR)_$(1):=$(2)
else
ifeq ($($(1)), undefined)
$(PACKAGE_DIR)_$(1):=$(2)
else
$(PACKAGE_DIR)_$(1):=$($(1))
endif
endif
endef

define lift_undef
ifeq ($(origin $(PACKAGE_DIR)_$(1)), undefined)
ifneq ($($(1)), undefined)
$(PACKAGE_DIR)_$(1):=$($(1))
endif
endif
endef

define package_to_app_name
  $(subst __,_,$(patsubst rabbitmq%,rabbit_%,$(subst -,_,$(1))))
endef

$(eval $(call default_and_lift_var,SOURCE_DIR,$(PACKAGE_DIR)/src))
$(eval $(call default_and_lift_var,SOURCE_ERLS,$(wildcard $($(PACKAGE_DIR)_SOURCE_DIR)/*.erl)))

$(eval $(call default_and_lift_var,INCLUDE_DIR,$(PACKAGE_DIR)/include))
$(eval $(call default_and_lift_var,INCLUDE_HRLS,$(wildcard $($(PACKAGE_DIR)_INCLUDE_DIR)/*.hrl)))

$(eval $(call default_and_lift_var,GENERATED_ERLS,))
$(PACKAGE_DIR)_SOURCE_ERLS:=$($(PACKAGE_DIR)_SOURCE_ERLS) $($(PACKAGE_DIR)_GENERATED_ERLS)

$(eval $(call default_and_lift_var,EBIN_DIR,$(PACKAGE_DIR)/ebin))
$(eval $(call default_and_lift_var,EBIN_BEAMS,$(patsubst $($(PACKAGE_DIR)_SOURCE_DIR)/%.erl,$($(PACKAGE_DIR)_EBIN_DIR)/%.beam,$($(PACKAGE_DIR)_SOURCE_ERLS))))

$(eval $(call default_and_lift_var,APP_NAME,$(call package_to_app_name,$(PACKAGE_NAME))))
$(eval $(call default_and_lift_var,OUTPUT_EZS,$(PACKAGE_NAME).ez))
$(eval $(call default_and_lift_var,DEPS_FILE,$(PACKAGE_DIR)/deps.mk))

$(foreach VAR,$(VARS),$(eval $(call lift_undef,$(VAR))))

# $(info I am $(PACKAGE_DIR) and my parents are $($(PACKAGE_DIR)_PARENTS))

define dump_var
$(1):=$($(1))
$(PACKAGE_DIR)_$(1):=$($(PACKAGE_DIR)_$(1))
endef

# $(foreach VAR,$(VARS),$(info $(call dump_var,$(VAR))))

ifeq "$(SET_DEFAULT_GOAL)" "true"
SET_DEFAULT_GOAL:=false
.DEFAULT_GOAL:=$(PACKAGE_DIR)_OUTPUT_EZS

.PHONY: $(PACKAGE_DIR)_OUTPUT_EZS
$(foreach EZ,$($(PACKAGE_DIR)_OUTPUT_EZS),$(eval $(PACKAGE_DIR)_OUTPUT_EZS: $(PACKAGE_DIR)/$(DIST_DIR)/$(EZ)))
endif

include ../common.mk

else
SET_DEFAULT_GOAL:=true
endif

include ../deps.mk
