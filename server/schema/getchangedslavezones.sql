CREATE OR REPLACE FUNCTION GetChangedSlaveZones(
	nameservername varchar,
	out change_id bigint,
	out change_name varchar,
	out change_changetime int
) RETURNS SETOF record AS $$
DECLARE r RECORD;
BEGIN
	FOR r IN	SELECT slavezone_change.id, zone, changetime FROM slavezone_change INNER JOIN nameserver ON nameserver_id = nameserver.id
			WHERE nameserver.name = nameservername AND status = 'PENDING' ORDER BY changetime ASC
	LOOP
		change_id := r.id;
		change_name := r.zone;
		change_changetime := r.changetime;
		RETURN NEXT;
	END LOOP;

	RETURN;
END; $$ LANGUAGE plpgsql;
