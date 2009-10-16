#!/bin/sh

cd dyndns
./buildpackages "$1"
cd ../syncer
./buildpackages "$1"
cd ../server
./buildpackages "$1"
cd ..
