CREATE OR REPLACE FUNCTION SetZoneMetadata(
	zonename varchar,
	metadata_keys varchar[],
	metadata_values varchar[]
) RETURNS VOID AS $$
DECLARE
	zone_check INT;
BEGIN
	IF (array_lower(metadata_keys, 1) <> array_lower(metadata_values, 1)) OR
	   (array_upper(metadata_keys, 1) <> array_upper(metadata_values, 1)) THEN
		RAISE EXCEPTION 'you have to have the same number of keys as values (and in the same order)';
	END IF;

        SELECT id INTO zone_check FROM zone WHERE zone.name = zonename;
        IF NOT FOUND THEN
                RAISE EXCEPTION 'zone % not found', zonename;
        END IF;

	DELETE FROM zone_metadata WHERE zone_id = zone_check;

	IF array_upper(metadata_keys, 1) IS NULL OR array_upper(metadata_keys, 1) = 0 THEN
		RETURN;
	ELSE
		FOR i IN array_lower(metadata_keys, 1) .. array_upper(metadata_keys, 1) LOOP
			INSERT INTO zone_metadata (zone_id, metadata_key, metadata_value)
			VALUES (zone_check, metadata_keys[i], metadata_values[i]);
		END LOOP;
	END IF; 
END; $$ LANGUAGE plpgsql;
