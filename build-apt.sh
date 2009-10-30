#!/bin/sh

if [ -z "$1" ]; then
        echo "usage: $0 ubuntu-version"
        exit 1
fi

cd dyndns
./buildpackages "$1"
cd ../syncer
./buildpackages "$1"
cd ../server
./buildpackages "$1"
cd ../zonefileimporter
./buildpackages "$1"
cd ..
