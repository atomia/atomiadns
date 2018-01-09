#!/bin/sh

if [ -z "$1" ] || [ -z "$2" ]; then
	echo "usage: $0 version message"
	echo "current version: "`grep ^Version syncer/SPECS/atomiadns-nameserver.spec | cut -d " " -f 2`
	exit 1
fi

version_to_number() {
	major=`echo "$1" | cut -d . -f 1`
	minor=`echo "$1" | cut -d . -f 2`
	patch=`echo "$1" | cut -d . -f 3`

	expr "$major" "*" 1000 + "$minor" "*" 100 + "$patch"
}

version="$1"
message="$2"

version_num=`version_to_number "$version"`
current_version=`grep ^Version syncer/SPECS/atomiadns-nameserver.spec | cut -d " " -f 2`
current_version_num=`version_to_number "$current_version"`

if [ -z "$version_num" ] || [ -z "$current_version_num" ]; then
	echo "error: calculating version number for $version or $current_version"
	exit 1
fi

if [ ! "$version_num" -gt "$current_version_num" ]; then
	echo "error: current version $current_version is not lower than $version"
	exit 1
fi

author_realname=`git config user.name`
author_email=`git config user.email`
if [ -z "$author_realname" ] || [ -z "$author_email" ]; then
	author="Jimmy Bergman <jimmy@atomia.com>"
else
	author="$author_realname <$author_email>"
fi

# Update *.spec
find dyndns syncer server powerdns_sync webapp -name "*.spec" -type f | while read f; do
	version_subs="%%s/^Version: .*/Version: $version/"
	require_subs="%%s/^Requires: atomiadns-api >= .* atomiadns-database >= .*/Requires: atomiadns-api >= $version atomiadns-database >= $version/"
	goto_changelog="/^%%changelog/+1i"
	change_header="* $(date +"%a %b %d %Y") $author - ${version}-1"
	ed_script=`printf "$version_subs\n$require_subs\n$goto_changelog\n$change_header\n- $message\n.\nw\nq\n"`
	echo "$ed_script" | ed "$f"
done

# Update */Makefile.PL
find dyndns syncer server zonefileimporter powerdns_sync webapp -name "Makefile.PL" | while read f; do
	version_subs="%%s/'VERSION' => '.*',/'VERSION' => '$version',/"
	ed_script=`printf "$version_subs\nw\nq\n"`
	echo "$ed_script" | ed "$f"
done

# Update */control
find dyndns syncer server zonefileimporter powerdns_sync webapp -name "control" | while read f; do
	version_subs='%%s/\\\\(atomiadns-[a-z]*\\\\) (>= [^)]*)/\\\\1 (>= '"$version"')/g'
	ed_script=`printf "$version_subs\nw\nq\n"`
	echo "$ed_script" | ed "$f"
done

# Update */changelog
find dyndns syncer server zonefileimporter powerdns_sync webapp -name "changelog" | while read f; do
	date=`date +"%a, %-d %b %Y %T %z"`
	package=`grep " hardy; " "$f" | head -n 1 | cut -d " " -f 1`
	changelog=`printf "%s (%s) hardy; urgency=low\n\n  * %s\n\n -- $author %s" "$package" "$version" "$message" "$date"`
	ed_script=`printf "1i\n%s\n\n.\nw\nq\n" "$changelog"`
	echo "$ed_script" | ed "$f"
done

# Update package.json
sed -i 's/\("version": "\)[^"]*"/\1'"$version"'"/' */package.json
