#!/bin/sh

dir=`dirname $0`
sql=`(cat "$dir"/ddl.sql
ls "$dir"/*.sql | grep -v ddl | grep -v example | xargs cat)`
sudo -u postgres psql zonedata -c "$sql"
