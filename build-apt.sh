#!/bin/sh

cd dyndns
../buildpackages
git checkout -- patches/Net/DNS/Nameserver.pm.orig
ret=$?
if [ $ret != 0 ]; then
	exit $ret
fi

cd ../syncer
../buildpackages
ret=$?
if [ $ret != 0 ]; then
	exit $ret
fi

cd ../server
../buildpackages
ret=$?
if [ $ret != 0 ]; then
	exit $ret
fi

cd ../zonefileimporter
../buildpackages
ret=$?
if [ $ret != 0 ]; then
	exit $ret
fi

cd ../powerdns_sync
../buildpackages
ret=$?
if [ $ret != 0 ]; then
	exit $ret
fi

cd ../webapp
../buildpackages
ret=$?
if [ $ret != 0 ]; then
	exit $ret
fi
