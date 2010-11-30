#!/bin/sh

. /usr/share/atomiadns/eventlibrary/afilias_sync/afilias_sync.conf

transfer_ip=`curl -v -k -u "$user:$pass" \
           -H "Content-Type: text/xml" \
           -X GET "$urlbase/nameservers/transfer/ipv4" 2>&1 | grep "<ipv4>" | sed 's/^.*<ipv4>\(.*\)<\/ipv4>.*$/\1/'`

if [ -n "$transfer_ip" ]; then
	already_allowed=`atomiadnsclient --method GetAllowedZoneTransfer | grep "'$transfer_ip'"`
	if [ -z "$already_allowed" ]; then
		echo "allowing transfers for $transfer_ip"
		atomiadnsclient --method AllowZoneTransfer --arg "*" --arg "$transfer_ip"
	fi
fi

exit 0
