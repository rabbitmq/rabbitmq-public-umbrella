#!/bin/sh

set -e

owner='VMware, Inc. or its affiliates.'
all_owners="(GoPivotal[^.]+\\.|Pivotal[^.]+\\.|VMware[^.]+\\. or its affiliates\\.)"

owner_and_link='<a href="https://tanzu.vmware.com/">VMware</a>, Inc. or its affiliates.'
all_owners_and_links="(<a[^>]*>GoPivotal</a>[^.]+\\.|<a[^>]*>Pivotal[^<]*</a>[^.]+\\.|<a[^>]*>VMware[^<]*</a>[^.]+\\. or its affiliates\\.)"

year=$(date +'%Y')
copyright_sign="(\\([Cc]\\)|©|&#169;)"

git grep -Ilz -i "copyright" "$@" > files-with-copyright.txt

sed=sed
if type gsed >/dev/null 2>&1; then
	sed=gsed
fi

xargs -0 \
$sed -E -i \
	-e "s@([Cc]opyright) +$copyright_sign +(20[0-9][0-9]) *[—-] *(20[0-9][0-9]|Present) +$all_owners@\\1 \\2 \\3-$year $owner@" \
	-e "s@([Cc]opyright) +$copyright_sign +(20[0-9][0-9]), *20[0-9][0-9] +$all_owners@\\1 \\2 \\3-$year $owner@" \
	-e "s@([Cc]opyright) +$copyright_sign +(20[0-9][0-9]) +$all_owners@\\1 \\2 \\3-$year $owner@" \
	-e "s@([Cc]opyright) +$copyright_sign +$year-$year +$all_owners@\\1 \\2 $year $owner@" \
	-e "s@([Cc]opyright) +$copyright_sign +$all_owners@\\1 \\2 2007-$year $owner@" \
	\
	-e "s@([Cc]opyright) +$copyright_sign +(20[0-9][0-9]) *[—-] *(20[0-9][0-9]|Present) +$all_owners_and_links@\\1 \\2 \\3-$year $owner_and_link@" \
	-e "s@([Cc]opyright) +$copyright_sign +(20[0-9][0-9]), *20[0-9][0-9] +$all_owners_and_links@\\1 \\2 \\3-$year $owner_and_link@" \
	-e "s@([Cc]opyright) +$copyright_sign +(20[0-9][0-9]) +$all_owners_and_links@\\1 \\2 \\3-$year $owner_and_link@" \
	-e "s@([Cc]opyright) +$copyright_sign +$year-$year +$all_owners_and_links@\\1 \\2 $year $owner_and_link@" \
	-e "s@([Cc]opyright) +$copyright_sign +$all_owners_and_links@\\1 \\2 2007-$year $owner_and_link@" \
	\
	-e "s@([Cc]opyright)(:?) +(20[0-9][0-9]) *[—-] *(20[0-9][0-9]|Present) +$all_owners@\\1\\2 \\3-$year $owner@" \
	-e "s@([Cc]opyright)(:?) +(20[0-9][0-9]), *20[0-9][0-9] +$all_owners@\\1\\2 \\3-$year $owner@" \
	-e "s@([Cc]opyright)(:?) +(20[0-9][0-9]) +$all_owners@\\1\\2 \\3-$year $owner@" \
	-e "s@([Cc]opyright)(:?) +$year-$year +$all_owners@\\1\\2 $year $owner@" \
	-e "s@([Cc]opyright)(:?) +$all_owners@\\1\\2 2007-$year $owner@" \
	\
	-e "s@$copyright_sign +$all_owners[^,]*, +(20[0-9][0-9]) *[—-] *(20[0-9][0-9]|Present)(\\.|\$)@\\1 \\3-$year $owner@" \
	-e "s@$copyright_sign +$all_owners[^,]*, +(20[0-9][0-9]), *20[0-9][0-9](\\.|\$)@\\1 \\3-$year $owner@" \
	-e "s@$copyright_sign +$all_owners[^,]*, +(20[0-9][0-9])([^-]+|\$)(\\.|\$)@\\1 \\3-$year\\4 $owner@" \
	-e "s@$copyright_sign +$all_owners[^,]*, +$year-$year(\\.|\$)@\\1 $year $owner@" \
	-e "s@$copyright_sign +$all_owners[^,]*(\\.|\$)@\\1 $owner@" \
	\
	-e "s@$copyright_sign +(20[0-9][0-9]) *[—-] *(20[0-9][0-9]|Present) +$all_owners@\\1 \\2-$year $owner@" \
	-e "s@$copyright_sign +(20[0-9][0-9]), *20[0-9][0-9] +$all_owners@\\1 \\2-$year $owner@" \
	-e "s@$copyright_sign +(20[0-9][0-9]) +$all_owners@\\1 \\2-$year $owner@" \
	-e "s@$copyright_sign +$year-$year +$all_owners@\\1 $year $owner@" \
	-e "s@$copyright_sign +$all_owners@\\1 2007-$year $owner@" \
< files-with-copyright.txt

if test "$DO_COMMIT" = 'yes'; then
	git diff --quiet || \
	xargs -0 \
	git commit -m "Update copyright (year $year)" \
	< files-with-copyright.txt
fi

rm files-with-copyright.txt
