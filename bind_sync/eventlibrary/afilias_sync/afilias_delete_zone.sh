#!/bin/sh

. /usr/share/atomiadns/eventlibrary/afilias_sync/afilias_sync.conf

if [ -z "$1" ]; then
	echo "usage: $0 domain"
	exit
fi

get_output=`curl -v -k -u "$user:$pass" \
           -H "Content-Type: text/xml" \
           -X DELETE "$urlbase/domains/secondary/$1" 2>&1`

if [ -n "$(echo "$get_output" | grep "HTTP/1.1 200 OK")" ]; then
	echo "slave $1 removed from account"
	exit 0
else
	echo "error removing slave $1: $get_output"
	exit 1
fi
