#!/bin/sh

if [ -z "$1" ]; then
	echo "usage: $0 version"
	exit 1
fi

svn add packages/*"$1"*
svn commit -m "Release apt-packages for version $1"

scp packages/*"$1"*.deb root@rpm.atomia.com:/home/pingdom
ssh root@rpm.atomia.com 'cd /var/packages/ubuntu && reprepro includedeb hardy /home/pingdom/atomiadns-*'"$1"'*.deb'
