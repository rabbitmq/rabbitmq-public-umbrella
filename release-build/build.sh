#!/usr/bin/env bash

# An automated rabbitmq build script
#
# Example Usage:
# release-build/build.sh BUILD_USERHOST=etch VERSION=1.7.$[`date +'%Y%m%d'` - 20090000] WIN_USERHOST="David Wragg@192.168.122.85" DEPLOY_USERHOST=mrbraver.lshift.net

# You should provide values for the following variables on the command line:

# The RabbitMQ version number, X.Y.Z
VERSION=

# The ssh user@host to use for the main build
BUILD_USERHOST=

# The windows ssh user@host to use for the windows bits.  If you omit
# it, the windows bits won't get built.
WIN_USERHOST=

# The Mac ssh user@host to use for the mac bits.  If you omit
# it, the mac bits won't get built.
MAC_USERHOST=

# Setting the following variables is optional.

# Options to pass to ssh commands.  '-i identity_file' is useful for
# using a special ssh key.
SSH_OPTS=

# Optional custom git url base.
GITREPOBASE=

# Where the keys live.  If not set, we will do an "unofficial release"
KEYSDIR=

# Other signing parameters to pass to the rabbitmq-public-umbrella Makefile.
# If KEYSDIR isn't pointing to the release keys, you will need to
# supply something here to set the Makefile's SIGNING_* vars.
SIGNING_KEY=

# The email address field to use in package changelog
# entries.  If you omit this, changelog entries won't be added.
CHANGELOG_EMAIL=packaging@rabbitmq.com

# The full name to use in package changelog # entries, if an entry is added.
CHANGELOG_FULLNAME="RabbitMQ Team"

# The revision of Debian and RPM packageS.
CHANGELOG_PKG_REV="1"

# The comment for changelog entires
CHANGELOG_COMMENT="New upstream release"

# Where auxiliary scripts live
SCRIPTDIR=$(dirname $0)

# Where the rabbitmq-public-umbrella repo lives.  If not set, we assume it is
# the grandparent-directory of this script.
UMBRELLADIR=

# OTP version to build against
OTP_VERSION="18.3"

# OTP version for the standalone package
STANDALONE_OTP_VERSION="18.3"

# Imitate make-style variable settings as arguments
while [[ $# -gt 0 ]] ; do
  declare "$1"
  shift
done

mandatory_vars="VERSION"
optional_vars="SSH_OPTS KEYSDIR SIGNING_KEY CHANGELOG_EMAIL CHANGELOG_FULLNAME CHANGELOG_PKG_REV CHANGELOG_COMMENT SCRIPTDIR UMBRELLADIR BUILD_USERHOST WIN_USERHOST MAC_USERHOST"

. $SCRIPTDIR/utils.sh
absolutify_scriptdir

[[ -n "$UMBRELLADIR" ]] || UMBRELLADIR=$SCRIPTDIR/..

[[ -n "$ROOT_USERHOST" ]] || ROOT_USERHOST=$(echo "$BUILD_USERHOST" | sed 's|^[^@]*@||;s|^|root@|')

[[ -z "$KEYSDIR" ]] && UNOFFICAL_RELEASE=1

[[ -n "$GITREPOBASE" ]] || GITREPOBASE="https://github.com/rabbitmq"

check_vars

set -e -x

# Check that a few more obscure bits we need on the master are present
if ! python -c "import pexpect" >/dev/null 2>&1 ; then
    echo ERROR: python-pexpect missing
    exit 1
fi
if ! rpm --help >/dev/null 2>&1 ; then
    echo ERROR: rpm missing
    exit 1
fi
if ! reprepro --help >/dev/null 2>&1 ; then
    echo ERROR: reprepro missing
    exit 1
fi

# Verify that we can ssh into the hosts, just in case
[ -n "$BUILD_USERHOST" ] && ssh $SSH_OPTS $BUILD_USERHOST 'true'
[ -n "$BUILD_USERHOST" ] && ssh $SSH_OPTS $ROOT_USERHOST 'true'
[ -n "$WIN_USERHOST" ] && ssh $SSH_OPTS "$WIN_USERHOST" 'true'
[ -n "$MAC_USERHOST" ] && ssh $SSH_OPTS "$MAC_USERHOST" 'true'

# Prepare the build host.
[ -n "$BUILD_USERHOST" ] && ssh $SSH_OPTS $ROOT_USERHOST '
    set -e -x
    case "$(cat /etc/debian_version)" in
    7.*)
        java_package=openjdk-6-jdk
        uja_command="update-java-alternatives -s java-1.6.0-openjdk"
        ;;
    *)
        echo "Not sure which JDK package to install"
        exit 1
    esac

    case `uname -m` in
    i686*)
        ARCH=i386
        ;;
    x86_64*)
        ARCH=amd64
        ;;
    *)
        echo Unrecognised architecture `uname -m`
        exit 1
    esac

    DEBIAN_FRONTEND=noninteractive ; export DEBIAN_FRONTEND
    apt-get -y update
    apt-get -y dist-upgrade
    apt-get -y install ncurses-dev rsync cdbs elinks python-simplejson rpm tofrodos zip unzip ant $java_package htmldoc plotutils transfig graphviz docbook-utils texlive-fonts-recommended gs-gpl python2.5 erlang-dev erlang-nox erlang-src python-pexpect openssl s3cmd fakeroot git-core m4 xmlto mercurial xsltproc nsis
    [ -n "$uja_command" ] && eval $uja_command
'

(cd $UMBRELLADIR/deps/rabbit && git checkout -- \
	packaging/debs/Debian/debian/changelog \
	packaging/RPMS/Fedora/rabbitmq-server.spec)

${MAKE:-make} -C "$UMBRELLADIR" release sign-artifacts  \
	${VERSION:+VERSION="$VERSION"} \
	${BUILD_USERHOST:+UNIX_HOST="$BUILD_USERHOST"} \
	${MAC_USERHOST:+MACOSX_HOST="$MAC_USERHOST"} \
	${WIN_USERHOST:+WINDOWS_HOST="$WIN_USERHOST"} \
	${KEYSDIR:+KEYSDIR="$KEYSDIR"} \
	${SIGNING_KEY:+SIGNING_KEY="$SIGNING_KEY"} \
	${CHANGELOG_FULLNAME:+CHANGELOG_NAME="$CHANGELOG_FULLNAME"} \
	${CHANGELOG_EMAIL:+CHANGELOG_EMAIL="$CHANGELOG_EMAIL"} \
	${CHANGELOG_PKG_REV:+CHANGELOG_PKG_REV="$CHANGELOG_PKG_REV"} \
	${CHANGELOG_COMMENT:+CHANGELOG_COMMENT="$CHANGELOG_COMMENT"} \
	${UNOFFICIAL_RELEASE:+UNOFFICIAL_RELEASE="$UNOFFICIAL_RELEASE"}

echo "Build completed successfully!"
