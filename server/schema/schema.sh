#!/bin/sh

pg_user=`grep -i PostgreSQL /etc/passwd | cut -d : -f 1`
if [ -z "$pg_user" ]; then
	echo "unable to find postgresql user, defaulting to postgres"
	pg_user="postgres"
fi

dir=`dirname $0`
sql=`(cat "$dir"/ddl.sql
ls "$dir"/*.sql | grep -v ddl | grep -v example | xargs cat)`
sudo -u "$pg_user" psql zonedata -c "$sql"
