#!/bin/bash

# The deployment counterpart to build.sh

# You should provide values for the following variables on the command line:

# The RabbitMQ version number, X.Y.Z
VERSION=

# Setting the following variables is optional.

# Options to pass to ssh commands.  '-i identity_file' is useful for
# using a special ssh key.
SSH_OPTS=

# Where the keys live.  If not set, we will do an "unofficial release"
KEYSDIR=

# The base URL of the rabbitmq website where the results of the build
# will actually be available.  Optional, defaults to the rabbitmq.com
# site
REAL_WEB_URL=http://www.rabbitmq.com/

# The Apple Mac OS host with macports installed used for generating
# the macports artifacts
MACPORTS_USERHOST=

# RSync user/host to deploy to.  If empty, we don't deploy.
DEPLOY_USERHOST=

# The directory on the local host to use for the build.  If not set,
# we will use a uniquely-named directory in /var/tmp.
TOPDIR=

# Which rabbitmq-umbrella deploy target to invoke
DEPLOY_TARGET=deploy-stage

# Where auxiliary scripts live
SCRIPTDIR=$(dirname $0)

# Imitate make-style variable settings as arguments
while [[ $# -gt 0 ]] ; do
  declare "$1"
  shift
done

mandatory_vars="VERSION"
optional_vars="SSH_OPTS KEYSDIR REAL_WEB_URL MACPORTS_USERHOST DEPLOY_USERHOST TOPDIR DEPLOY_TARGET SCRIPTDIR"

. $SCRIPTDIR/utils.sh
absolutify_scriptdir

[[ -n "$TOPDIR" ]] || TOPDIR="$SCRIPTDIR/../.."

check_vars

set -e -x

vars="VERSION=$VERSION REAL_WEB_URL=$REAL_WEB_URL MACPORTS_USERHOST=\"$MACPORTS_USERHOST\" SSH_OPTS=\"$SSH_OPTS\" STAGE_DEPLOY_HOST=\"$DEPLOY_USERHOST\" LIVE_DEPLOY_HOST=\"$DEPLOY_USERHOST\" NIGHTLY_DEPLOY_HOST=\"$DEPLOY_USERHOST\" GNUPG_PATH=$KEYSDIR/keyring"

# The maven deployment bits need access to credentials under KEYSDIR
if [ -n "$KEYSDIR" ] ; then
    vars="$vars GNUPG_PATH=$KEYSDIR/keyring $SIGNING_PARAMS"
fi

# Build macports
cd $TOPDIR/rabbitmq-umbrella
eval "make rabbitmq-server-macports-packaging $vars"

# Finally, deploy
if [[ -n "$DEPLOY_USERHOST" ]] ; then
    eval "make $DEPLOY_TARGET $vars"
fi
