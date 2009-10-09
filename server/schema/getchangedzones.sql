CREATE OR REPLACE FUNCTION GetChangedZones(
	nameservername varchar,
	out change_id int,
	out change_name varchar,
	out change_changetime int
) RETURNS SETOF record AS $$
DECLARE r RECORD;
BEGIN
	FOR r IN	SELECT MAX(change.id) AS id, zone, MAX(changetime) AS changetime FROM change INNER JOIN nameserver ON nameserver_id = nameserver.id 
			WHERE nameserver.name = nameservername AND status = 'PENDING'
			GROUP BY zone
	LOOP
		change_id := r.id;
		change_name := r.zone;
		change_changetime := r.changetime;
		RETURN NEXT;
	END LOOP;

	RETURN;
END; $$ LANGUAGE plpgsql;
