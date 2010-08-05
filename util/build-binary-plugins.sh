#!/bin/sh -e

UMBRELLA=rabbitmq-public-umbrella/
ABSOLUTE_PLUGINS_DIR=$(dirname $(readlink -f $0))/../${PLUGINS_DIST_DIR}

make -C ${UMBRELLA} PLUGINS_DIST_DIR=${ABSOLUTE_PLUGINS_DIR} \
    VERSION=${VERSION} plugins-dist
