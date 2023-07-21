CREATE OR REPLACE FUNCTION GetZoneStatusBulk(
	zonenames varchar[],
	out zonename varchar,
	out zonestatus varchar
) RETURNS SETOF record AS $$
DECLARE

BEGIN
	IF zonenames IS NOT NULL AND array_length(zonenames, 1) > 0 THEN
		FOR i IN array_lower(zonenames, 1) .. array_upper(zonenames, 1) LOOP
			zonename := zonenames[i];
			SELECT status INTO zonestatus FROM zone WHERE name = zonenames[i];
			IF NOT FOUND THEN
				zonestatus := 'nonexistent';
			END IF;
		RETURN NEXT;
		END LOOP;
	END IF;

	RETURN;
END; $$ LANGUAGE plpgsql;
