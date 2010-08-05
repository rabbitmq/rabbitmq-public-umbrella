#!/bin/sh -e

TEMP_DIR=`mktemp -d`
UMBRELLA=${TEMP_DIR}/rabbitmq-public-umbrella/
HG_CORE_REPOBASE=$(dirname $(hg paths default 2>/dev/null))

hg clone ${HG_CORE_REPOBASE}/rabbitmq-public-umbrella/ ${UMBRELLA}

make -C ${UMBRELLA} checkout
make -C ${UMBRELLA} TAG=${TAG} tag
make -C ${UMBRELLA} push
rm -rf ${TEMP_DIR}
