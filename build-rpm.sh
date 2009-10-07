#!/bin/sh

if [ -z "$1" ]; then
	echo "usage: $0 redhat-version"
	exit 1
fi

cd dyndns
./buildrpms "$1"
cd ../syncer
./buildrpms "$1"
cd ../server
./buildrpms "$1"
cd ..
