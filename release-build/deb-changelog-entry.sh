#!/bin/sh
# vim:sw=4:et:

set -e

CHANGELOG=$1
if [ -z "$CHANGELOG" -o ! -f "$CHANGELOG" ]; then
    echo "Syntax: $(basename "$0") <debian/changelog file>" 1>&2
    exit 1
fi

if [ -z "$VERSION" ]; then
    echo "$(basename "$0"): ERROR:" \
        "The environment variable \$VERSION must be set" 1>&2
    exit 1
fi

if dpkg-parsechangelog -l"$CHANGELOG" | \
  grep -E -q "^Version: ${VERSION}-${CHANGELOG_PKG_REV}"; then
    echo "$(basename "$0"):" \
        "Using existing entry for ${VERSION}-${CHANGELOG_PKG_REV}"
    exit 0
fi

[ "$CHANGELOG_EMAIL" ]   || CHANGELOG_EMAIL='packaging@rabbitmq.com'
[ "$CHANGELOG_NAME" ]    || CHANGELOG_NAME='RabbitMQ Team'
[ "$CHANGELOG_PKG_REV" ] || CHANGELOG_PKG_REV=1
[ "$CHANGELOG_COMMENT" ] || CHANGELOG_COMMENT='New upstream release'

cd $(dirname "$CHANGELOG")

DEBNAME="$CHANGELOG_NAME"
DEBEMAIL="$CHANGELOG_EMAIL"
export DEBNAME DEBEMAIL

dch -v ${VERSION}-${CHANGELOG_PKG_REV} --check-dirname-level 0 \
    --distribution unstable --force-distribution "$CHANGELOG_COMMENT"

if test -f "$CHANGELOG_ADDITIONAL_COMMENTS_FILE"; then
    while read ADDTNL_COMMENTS; do
        if $(echo "$ADDTNL_COMMENTS" | grep -qv '^#'); then
            dch --append --check-dirname-level 0 \
                --distribution unstable --force-distribution \
                "$ADDTNL_COMMENTS";
        fi
    done < "$CHANGELOG_ADDITIONAL_COMMENTS_FILE"
fi
