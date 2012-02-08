#!/bin/sh

version=`cat /etc/redhat-release | sed 's/[^0-9.]//g' | cut -d . -f 1`

rm -f *rpm
rm -f /usr/src/redhat/RPMS/*/atomiadns-*
rm -f /usr/src/redhat/SRPMS/atomiadns-*

cd dyndns
./buildrpms rhel"$version"
ret=$?
if [ $ret != 0 ]; then
	exit $ret
fi

cd ../syncer
./buildrpms rhel"$version"
ret=$?
if [ $ret != 0 ]; then
	exit $ret
fi

cd ../server
./buildrpms rhel"$version"
ret=$?
if [ $ret != 0 ]; then
	exit $ret
fi

#cd ../zonefileimporter
#./buildrpms rhel"$version"
#ret=$?
#if [ $ret != 0 ]; then
#	exit $ret
#fi

cd ../powerdns_sync
./buildrpms rhel"$version"
ret=$?
if [ $ret != 0 ]; then
	exit $ret
fi

cd ..
