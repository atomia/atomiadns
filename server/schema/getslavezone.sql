CREATE OR REPLACE FUNCTION GetSlaveZone(
	zonename varchar,
	out record_zone varchar,
	out record_master varchar,
	out record_tsig_name varchar,
	out record_tsig_secret varchar
) RETURNS SETOF record AS $$
DECLARE
	r RECORD;
	zone_check INT;
BEGIN
        SELECT id INTO zone_check FROM slavezone WHERE name = zonename;
        IF NOT FOUND THEN
                RAISE EXCEPTION 'slave zone % not found', zonename;
        END IF;

	FOR r IN	SELECT name, master, tsig_name, tsig_secret FROM slavezone WHERE name = zonename
	LOOP
		record_zone := r.name;
		record_master := r.master;
		record_tsig_name := r.tsig_name;
		record_tsig_secret := r.tsig_secret;
		RETURN NEXT;
	END LOOP;

	RETURN;
END; $$ LANGUAGE plpgsql;
