#!/bin/sh

ods_control=`whereis ods-control | awk '{ print $2 }'`
if [ -z "$ods_control" ]; then
	ods_control="ods-control"
fi

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
if [ $? = 0 ]; then
	echo "$zone found in OpenDNSSEC installation, removing"

	"$ods_control" ksm zone delete -z "$zone"
	if [ $? != 0 ]; then
		echo "error removing zone to opendnssec, retval=$?"
		exit 1
	fi

	"$ods_control" ksm update conf
	if [ $? != 0 ]; then
		echo "error updating opendnssec config, retval=$?"
		exit 1
	fi
fi

exit 0

