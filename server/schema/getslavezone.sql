CREATE OR REPLACE FUNCTION GetSlaveZone(
	zonename varchar,
	out record_zone varchar,
	out record_master varchar
) RETURNS SETOF record AS $$
DECLARE
	r RECORD;
	zone_check INT;
BEGIN
        SELECT id INTO zone_check FROM slavezone WHERE name = zonename;
        IF NOT FOUND THEN
                RAISE EXCEPTION 'slave zone % not found', zonename;
        END IF;

	FOR r IN	SELECT name, master FROM slavezone WHERE name = zonename
	LOOP
		record_zone := r.name;
		record_master := r.master;
		RETURN NEXT;
	END LOOP;

	RETURN;
END; $$ LANGUAGE plpgsql;
