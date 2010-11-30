#!/bin/sh

. /usr/share/atomiadns/eventlibrary/afilias_sync/afilias_sync.conf

if [ -z "$1" ]; then
	echo "usage: $0 domain"
	exit
fi

get_output=`curl -v -k -u "$user:$pass" \
           -H "Content-Type: text/xml" \
           -X GET "$urlbase/domains/secondary/$1" 2>&1`

if [ -n "$(echo "$get_output" | grep "<code>object_not_found</code>")" ]; then
	put_output=`curl -v -k -u "$user:$pass" \
		-H "Content-Type: text/xml" \
		-d "<xfr_target_list><xfr_target><ip>$zone_transfer_ip</ip><port>53</port></xfr_target></xfr_target_list>" \
		-X PUT "$urlbase/domains/secondary/$1" 2>&1`

	if [ -n "$(echo "$put_output" | grep "HTTP/1.1 200 OK")" ]; then
		echo "slave $1 added successfully"
		exit 0
	else
		echo "error adding slave $1, output was: $put_output"
		exit 1
	fi
elif [ -n "$(echo "$get_output" | grep "HTTP/1.1 200 OK")" ]; then
	echo "slave $1 already in account"

	notify_ip=`curl -k -u "$user:$pass" \
		-H "Content-Type: text/xml" \
		-X GET "$urlbase/nameservers/notify/ipv4" 2>&1 | grep "<ipv4>" | sed 's/^.*<ipv4>\(.*\)<\/ipv4>.*$/\1/'`
	if [ -n "$notify_ip" ]; then
		echo "notifying $notify_ip with DNS NOTIFY"
		/usr/share/atomiadns/eventlibrary/dns_notify.pl "$1" "$notify_ip"
	fi
	exit 0
else
	echo "error adding slave $1: $get_output"
	exit 1
fi
