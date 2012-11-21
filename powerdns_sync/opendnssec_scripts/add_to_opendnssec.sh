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

tempf=`mktemp || exit 1`

"$ods_control" ksm zone add -z "$zone" > "$tempf" 2>&1
retval=$?
if [ $retval != 0 ]; then
	if fgrep "it already exists" "$tempf" > /dev/null; then
		rm -f "$tempf"
		exit 0
	else
		echo "error adding zone to opendnssec, retval=$retval, output was:"
		cat "$tempf"
		rm -f "$tempf"
		exit 1
	fi
fi

rm -f "$tempf"

echo "$zone not found in OpenDNSSEC installation, added it successfully, now updating conf"

"$ods_control" ksm update conf
retval=$?
if [ $retval != 0 ]; then
	echo "error updating opendnssec config, retval=$retval"
	exit 1
fi

exit 0

