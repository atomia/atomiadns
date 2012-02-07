#!/bin/sh

version=`cat /etc/redhat-release | sed 's/[^0-9.]//g' | cut -d . -f 1`

cd dyndns
./buildrpms rhel"$version"
cd ../syncer
./buildrpms rhel"$version"
cd ../server
./buildrpms rhel"$version"
cd ../zonefileimporter
#./buildrpms rhel"$version"
cd ../powerdns_sync
./buildrpms rhel"$version"
cd ..
