#!/bin/sh

cd dyndns
./buildrpms rhel5
cd ../syncer
./buildrpms rhel5
cd ../server
./buildrpms rhel5
cd ../zonefileimporter
#./buildrpms rhel5
cd ..
