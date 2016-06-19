#!/usr/bin/env bash

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

# Mac OS X host used to produce OS X-specific artifacts
MAC_USERHOST=

# RSync user/host to deploy to.  If empty, we don't deploy.
DEPLOY_USERHOST=

# PATH on DEPLOY_USERHOST to deploy to.
DEPLOY_PATH=/home/rabbitmq/extras/releases

# Where auxiliary scripts live
SCRIPTDIR=$(dirname $0)

# Imitate make-style variable settings as arguments
while [[ $# -gt 0 ]] ; do
  declare "$1"
  shift
done

mandatory_vars="VERSION"
optional_vars="SSH_OPTS KEYSDIR DEPLOY_USERHOST SCRIPTDIR"

. $SCRIPTDIR/utils.sh
absolutify_scriptdir

[[ -n "$UMBRELLADIR" ]] || UMBRELLADIR=$SCRIPTDIR/..

check_vars

set -e -x

TARGETS=deploy
if [ "$DEPLOY_TARGET" = 'deploy-live' ]; then
	TARGETS="$TARGETS deploy-maven"
fi

# Finally, deploy
if [ "$DEPLOY_USERHOST" ]; then
	${MAKE:-make} -C "$UMBRELLADIR" $TARGETS \
		${VERSION:+VERSION="$VERSION"} \
		${DEPLOY_USERHOST:+DEPLOY_HOST="$DEPLOY_USERHOST"} \
		${DEPLOY_PATH:+DEPLOY_PATH="$DEPLOY_PATH"} \
		${SSH_OPTS:+SSH_OPTS="$SSH_OPTS"} \
		${KEYSDIR:+KEYSDIR="$KEYSDIR"}
fi
