CREATE OR REPLACE FUNCTION GetTSIGKey(
	tsigkey_name varchar,
	out record_name varchar,
	out record_secret varchar,
	out record_algorithm varchar
) RETURNS SETOF record AS $$
DECLARE
	r RECORD;
	tsigkey_check INT;
BEGIN
        SELECT id INTO tsigkey_check FROM tsigkey WHERE name = tsigkey_name;
        IF NOT FOUND THEN
                RAISE EXCEPTION 'TSIG key % not found', tsigkey_name;
        END IF;

	FOR r IN	SELECT name, secret, algorithm FROM tsigkey WHERE name = tsigkey_name
	LOOP
		record_name := r.name;
		record_secret := r.secret;
		record_algorithm := r.algorithm;
		RETURN NEXT;
	END LOOP;

	RETURN;
END; $$ LANGUAGE plpgsql;
