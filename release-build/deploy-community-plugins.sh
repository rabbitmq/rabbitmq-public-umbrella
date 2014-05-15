#!/bin/bash

# Setting the following variables is optional.

# Options to pass to ssh commands.  '-i identity_file' is useful for
# using a special ssh key.
SSH_OPTS=

# RSync user/host to deploy to.  If empty, we don't deploy.
DEPLOY_USERHOST=www.rabbitmq.com

# PATH on DEPLOY_USERHOST to deploy to.
DEPLOY_PATH=/home/rabbitmq/extras/community-plugins/

# The directory on the local host as specified by the --build-dir
# argument to the build script
BUILD_DIR=/var/tmp/plugins-build/

# Where auxiliary scripts live
SCRIPTDIR=$(dirname $0)

# Imitate make-style variable settings as arguments
while [[ $# -gt 0 ]] ; do
  declare "$1"
  shift
done

mandatory_vars="BUILD_DIR"
optional_vars="SSH_OPTS DEPLOY_USERHOST DEPLOY_PATH BUILD_DIR SCRIPTDIR"

. $SCRIPTDIR/utils.sh
absolutify_scriptdir

check_vars

set -e -x

rsync -rpl $BUILD_DIR/plugins/ $DEPLOY_USERHOST:$DEPLOY_PATH