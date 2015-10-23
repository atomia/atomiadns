CREATE OR REPLACE FUNCTION DeleteZone (
	zonename varchar
) RETURNS void AS $$
DECLARE
	zone_id_var bigint;
BEGIN
	SELECT id INTO zone_id_var FROM zone WHERE name = zonename;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'zone % not found', zonename;
	END IF;

	DELETE FROM record USING label INNER JOIN zone ON zone_id = zone.id WHERE label_id = label.id AND zone.name = zonename;
	DELETE FROM label USING zone WHERE zone_id = zone.id AND zone.name = zonename;
	DELETE FROM zone_metadata USING zone WHERE zone_id = zone.id AND zone.name = zonename;
	DELETE FROM zone WHERE zone.name = zonename;
	DELETE FROM allow_zonetransfer WHERE zone = zonename;
END; $$ LANGUAGE plpgsql;
