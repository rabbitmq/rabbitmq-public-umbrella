#!/bin/bash -e

# The ssh user@host to use for the main build
BUILD_USERHOST=

# The URL to clone to get the plugin
URL=

# The app name that will form part of the .ez name.
APP=

# Plugin version to build
VERSION=

# RabbitMQ version to build against
RABBITMQ_VERSION=

# RSync user/host to deploy to.
DEPLOY_USERHOST=

# Options to pass to ssh commands.  '-i identity_file' is useful for
# using a special ssh key.
SSH_OPTS=

# Where auxiliary scripts live
SCRIPTDIR=$(dirname $0)

# Imitate make-style variable settings as arguments
while [[ $# -gt 0 ]] ; do
  declare "$1"
  shift
done

mandatory_vars="URL APP BUILD_USERHOST DEPLOY_USERHOST"
optional_vars="RABBITMQ_VERSION VERSION SSH_OPTS TOPDIR topdir"

. $SCRIPTDIR/utils.sh
absolutify_scriptdir

# Lower-case topdir is the directory in /var/tmp where we do the build
# on the remote hosts.  TOPDIR may be different.
topdir=/var/tmp/rabbit-build.$$
[[ -z "$TOPDIR" ]] && TOPDIR="$topdir"

[[ -n "$HGREPOBASE" ]] || HGREPOBASE="ssh://hg@rabbit-hg"
[[ -n "$VERSION" ]] || VERSION=master
[[ -n "$RABBITMQ_VERSION" ]] || RABBITMQ_VERSION=$(hg tags | grep rabbitmq | head -n 1 | cut -f 1 -d " ")

check_vars

checkout_dir=$(echo $URL | grep -o '[^/]*$' | grep -o '^[^.]*')
rabbitmq_version_dir=$(echo $RABBITMQ_VERSION | cut -b 10- | tr _ .)
rabbitmq_version_file=$(echo $RABBITMQ_VERSION | cut -b 11- | tr _ .)

# Verify that we can ssh into the hosts, just in case
ssh $SSH_OPTS $BUILD_USERHOST 'true'

hg clone -e "ssh $SSH_OPTS" -r $RABBITMQ_VERSION \
    "$HGREPOBASE/rabbitmq-public-umbrella" $TOPDIR/rabbitmq-public-umbrella

echo TOPDIR=$TOPDIR

cd $TOPDIR/rabbitmq-public-umbrella
for dep in rabbitmq-server rabbitmq-erlang-client rabbitmq-codegen ; do
    make $dep
    hg up -r $RABBITMQ_VERSION -R $dep
done

git clone -b $VERSION $URL
HASH=$(git --git-dir=$checkout_dir/.git rev-parse HEAD | cut -b 1-8)

rsync -a $TOPDIR/ $BUILD_USERHOST:$topdir

vars="VERSION=$rabbitmq_version_file-$HASH"

ssh $SSH_OPTS $BUILD_USERHOST '
    set -e -x
    PATH=$HOME/otp-R12B-5/bin:$PATH
    cd '$topdir'
    cd rabbitmq-public-umbrella/'$checkout_dir'
    { make '"$vars"' ERLANG_CLIENT_OTP_HOME=$HOME/otp-R12B-5 && touch dist.ok ; } 2>&1 | tee dist.log ; test -e dist.ok
'

# Copy everything back from the build host
rsync -a $BUILD_USERHOST:$topdir/ $TOPDIR
ssh $SSH_OPTS $BUILD_USERHOST "rm -rf $topdir"

mkdir -p $TOPDIR/to-upload/$rabbitmq_version_dir
cp $TOPDIR/rabbitmq-public-umbrella/$checkout_dir/dist/$APP*.ez $TOPDIR/to-upload/$rabbitmq_version_dir

rsync -rpl $TOPDIR/to-upload/ $DEPLOY_USERHOST:/home/rabbitmq/extras/community-plugins/

rm -rf $TOPDIR
echo "Build completed successfully"
