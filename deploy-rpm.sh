#!/bin/sh

if [ -z "$1" ] || [ -z "$2" ]; then
	echo "usage: $0 version redhat-version"
	exit 1
fi

scp packages/*"$1"*.rpm root@rpm.atomia.com:/var/packages/"$2"
ssh root@rpm.atomia.com createrepo /var/packages/"$2"
