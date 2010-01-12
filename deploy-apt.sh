#!/bin/sh

if [ -z "$1" ] || [ -z "$2" ]; then
	echo "usage: $0 version ubuntu-version"
	exit 1
fi

svn add packages/"$2"/*"$1"*
svn commit -m "Release apt-packages for version $1 on $2"

scp packages/"$2"/*"$1"*.deb root@apt.atomia.com:/home/pingdom
ssh root@rpm.atomia.com "cd /var/packages/ubuntu-$2 && reprepro includedeb $2 /home/pingdom/atomiadns-*$1*.deb"
./wikify_releasenotes.sh
