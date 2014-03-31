CREATE OR REPLACE FUNCTION GetAllZones(
	out id bigint,
	out name varchar
) RETURNS SETOF record AS $$
DECLARE r RECORD;
BEGIN
	FOR r IN	SELECT * FROM zone
	LOOP
		id := r.id;
		name := r.name;
		RETURN NEXT;
	END LOOP;

	RETURN;
END; $$ LANGUAGE plpgsql;
