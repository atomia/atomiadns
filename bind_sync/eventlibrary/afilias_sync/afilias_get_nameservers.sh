#!/bin/sh

. /usr/share/atomiadns/eventlibrary/afilias_sync/afilias_sync.conf

curl -s -k -u "$user:$pass" \
	-H "Content-Type: text/xml" \
	-X GET "$urlbase/nameservers/names" 2>&1 | tr "<" "\n" | grep "^name>" | cut -d ">" -f 2
exit 0
