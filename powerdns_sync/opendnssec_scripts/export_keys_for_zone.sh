#!/bin/sh

ods_control=`whereis ods-control | awk '{ print $2 }'`
if [ -z "$ods_control" ]; then
	ods_control="ods-control"
fi

if [ -z "$1" ]; then
	echo "usage: $0 zone"
	exit 1
fi

key=`"$ods_control" ksm key export --zone "$1" 2> /dev/null | grep -v "^;" | sed 's/^[a-z0-9.-]*[[:space:]]/atomiadns.\t/' | tr -d "\n"`
retval=$?
if [ $retval != 0 ]; then
	echo "error exporting key, retval=$retval"
	exit $?
fi

echo "$key"
exit 0
