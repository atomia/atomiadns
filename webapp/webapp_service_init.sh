#!/bin/sh

if [ -f /usr/bin/lsb_release ] && [ `/usr/bin/lsb_release -rs` = "14.04" ]; then
	node_bin=`whereis -b nodejs | awk '{ print $2 }'`
else
	node_bin=`whereis -b node | awk '{ print $2 }'`
fi

if [ -z "$node_bin" ]; then
	echo "can't find node binary"
	exit 1
fi

if [ -f "/etc/atomiadns.conf" ]; then
	init_env=`mktemp` || exit 1
	temp_export=`mktemp` || exit 1
	grep -E '^(webapp|json)_' /etc/atomiadns.conf | perl -le 'while (<>) { /(.*?)\s*=\s*(.*)$/ && print uc($1) . "=\"" . $2 . "\""; }' > "$init_env"
	cut -d "=" -f 1 < "$init_env" | xargs echo export > "$temp_export"
	cat "$temp_export" >> "$init_env"
	. "$init_env"
	rm -f "$init_env" "$temp_export"
fi

exec "$node_bin" /usr/lib/atomiadns/webapp/atomiadns.js >> /var/log/atomiadns_webapp.log 2>&1
