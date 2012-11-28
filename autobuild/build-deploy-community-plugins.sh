#!/bin/bash -e

# The ssh user@host to use for the main build
BUILD_USERHOST=

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

mandatory_vars="BUILD_USERHOST DEPLOY_USERHOST"
optional_vars="SSH_OPTS RABBITMQ_VERSION"

. $SCRIPTDIR/utils.sh
absolutify_scriptdir

check_vars

plugin () {
    $SCRIPTDIR/build-deploy-community-plugin.sh \
        BUILD_USERHOST=$BUILD_USERHOST \
        RABBITMQ_VERSION=$RABBITMQ_VERSION DEPLOY_USERHOST=$DEPLOY_USERHOST \
        URL=$1 APP=$2
}

plugin https://github.com/tonyg/udp-exchange                        rabbit_udp_exchange
plugin https://github.com/tonyg/presence-exchange                   rabbit_presence_exchange
plugin https://github.com/simonmacmullen/rabbitmq-auth-backend-http rabbitmq_auth_backend_http
plugin https://github.com/simonmacmullen/rabbitmq-lvc-plugin        rabbitmq_lvc
