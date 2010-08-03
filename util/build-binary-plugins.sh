#!/bin/sh -e

TEMP_DIR=`mktemp -d`
UMBRELLA=${TEMP_DIR}/rabbitmq-public-umbrella/
HG_CORE_REPOBASE=$(dirname $(hg paths default 2>/dev/null))
ABSOLUTE_PLUGINS_DIR=$(dirname $(readlink -f $0))/${PLUGINS_DIST_DIR}

# TODO when this is merged remove the -r bug22980 from here
hg clone -r bug22980 ${HG_CORE_REPOBASE}/rabbitmq-public-umbrella/ ${UMBRELLA}

make -C ${UMBRELLA} checkout
if [ -z "${UNOFFICIAL_RELEASE}" ]; then
    make -C ${UMBRELLA} BRANCH=${TAG} named_update
fi
make -C ${UMBRELLA} PLUGINS_DIST_DIR=${ABSOLUTE_PLUGINS_DIR} \
    VERSION=${VERSION} plugins-dist
rm -rf ${TEMP_DIR}
