#!/bin/sh

ods_control="/usr/sbin/ods-control"

if [ -z "$1" ]; then
	echo "usage: $0 zone"
	exit 1
fi

zone="$1"

if [ ! -e "$ods_control" ] || [ ! -x "$ods_control" ]; then
	echo "$ods_control doesn't exist or isn't executable"
	exit 1
fi

"$ods_control" ksm zone list 2>&1 | fgrep "Found Zone: $zone;" > /dev/null 2>&1
if [ $? != 0 ]; then
	echo "$zone not found in OpenDNSSEC installation, adding"

	"$ods_control" ksm zone add -z "$zone"
	if [ $? != 0 ]; then
		echo "error adding zone to opendnssec, retval=$?"
		exit 1
	fi

	"$ods_control" ksm update conf
	if [ $? != 0 ]; then
		echo "error updating opendnssec config, retval=$?"
		exit 1
	fi
fi

exit 0

