CREATE OR REPLACE FUNCTION GetChangedTSIGKeys(
	nameservername varchar,
	out change_id bigint,
	out change_name varchar,
	out change_changetime int
) RETURNS SETOF record AS $$
DECLARE r RECORD;
BEGIN
	FOR r IN	SELECT tsigkey_change.id, tsigkey_name, changetime FROM tsigkey_change INNER JOIN nameserver ON nameserver_id = nameserver.id
			WHERE nameserver.name = nameservername AND status = 'PENDING' ORDER BY changetime ASC
	LOOP
		change_id := r.id;
		change_name := r.tsigkey_name;
		change_changetime := r.changetime;
		RETURN NEXT;
	END LOOP;

	RETURN;
END; $$ LANGUAGE plpgsql;
