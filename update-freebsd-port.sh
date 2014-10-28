#!/bin/sh

cd /usr/ports/dns

if [ ! -d "atomiadns-api" ]; then
	echo "you have to first add the ports to /usr/ports/dns, see http://atomia.github.io/atomiadns/usage.html#usage-master-installation-default-freebsd"
	exit 1
fi

if [ -z "$1" ]; then
	echo "usage: $0 version"
	exit 1
fi

for d in atomiadns-*; do
	cd "$d"
	make distclean
	sed -I "" -e 's/\(PORTVERSION=[[:space:]]\).*$/\1'"$1/" Makefile
	make makesum
	cd ..
done

echo "ports are now updated, next step is to rsync them to an Atomia DNS git repo, example used by current maintainer:"
echo 'rsync -a atomiadns-* jma@s1020.atomia.com:Dns/freebsd'
