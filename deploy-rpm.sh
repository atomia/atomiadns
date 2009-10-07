#!/bin/sh

if [ -z "$1" ] || [ -z "$2" ]; then
	echo "usage: $0 version redhat-version"
	exit 1
fi

svn add packages/"$2"/*"$version"*
svn commit -m "RPM version $1 for $2"

scp packages/"$2"/*"$1"*.rpm root@rpm.atomia.com:/var/packages/"$2"
ssh root@rpm.atomia.com createrepo /var/packages/"$2"
