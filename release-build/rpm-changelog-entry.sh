#!/bin/sh
# vim:sw=4:et:

set -e

SPEC=$1
if [ -z "$SPEC" -o ! -f "$SPEC" ]; then
    echo "Syntax: $(basename "$0") <.spec file>" 1>&2
    exit 1
fi

if [ -z "$VERSION" ]; then
    echo "$(basename "$0"): ERROR:" \
        "The environment variable \$VERSION must be set" 1>&2
    exit 1
fi

if grep -E -q "^\*.+ ${VERSION}-${CHANGELOG_PKG_REV}$" "$SPEC"; then
    echo "$(basename "$0"):" \
        "Using existing entry for ${VERSION}-${CHANGELOG_PKG_REV}"
    exit 0
fi

[ "$CHANGELOG_EMAIL" ]   || CHANGELOG_EMAIL='packaging@rabbitmq.com'
[ "$CHANGELOG_NAME" ]    || CHANGELOG_NAME='RabbitMQ Team'
[ "$CHANGELOG_PKG_REV" ] || CHANGELOG_PKG_REV=1
[ "$CHANGELOG_COMMENT" ] || CHANGELOG_COMMENT='New upstream release'

mv "$SPEC" "$SPEC~"

sed -E \
    -e "s/^(Release: *)[0-9]*(.*)/\1${CHANGELOG_PKG_REV}\2/" \
    -ne '0,/^%changelog/p' < "$SPEC~" > "$SPEC"

cat >> "$SPEC" <<EOF
* $(date +'%a %b %-d %Y') ${CHANGELOG_EMAIL} ${VERSION}-${CHANGELOG_PKG_REV}
- ${CHANGELOG_COMMENT}

EOF

sed -ne '/^%changelog/,$p' < "$SPEC~" | tail -n +2 >> "$SPEC"

rm "$SPEC~"
