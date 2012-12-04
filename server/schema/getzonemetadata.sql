CREATE OR REPLACE FUNCTION GetZoneMetadata(
	zonename varchar,
	out metadata_key varchar,
	out metadata_value varchar
) RETURNS SETOF record AS $$
DECLARE
	r RECORD;
	zone_check INT;
BEGIN
        SELECT id INTO zone_check FROM zone WHERE zone.name = zonename;
        IF NOT FOUND THEN
                RAISE EXCEPTION 'zone % not found', zonename;
        END IF;

	FOR r IN	SELECT m.metadata_key, m.metadata_value
			FROM zone INNER JOIN zone_metadata m ON zone.id = m.zone_id
			WHERE zone.name = zonename
	LOOP
		metadata_key := r.metadata_key;
		metadata_value := r.metadata_value;
		RETURN NEXT;
	END LOOP;

	RETURN;
END; $$ LANGUAGE plpgsql;
