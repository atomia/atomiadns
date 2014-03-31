CREATE OR REPLACE FUNCTION DeleteSlaveZone (
	zonename varchar
) RETURNS void AS $$
DECLARE
	zone_id_var bigint;
BEGIN
	SELECT id INTO zone_id_var FROM slavezone WHERE name = zonename;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'slave zone % not found', zonename;
	END IF;

	DELETE FROM slavezone WHERE name = zonename;
END; $$ LANGUAGE plpgsql;
