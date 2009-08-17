CREATE OR REPLACE FUNCTION GetLabels(
	zonename varchar
) RETURNS SETOF varchar AS $$
DECLARE
	zone_check INT;
BEGIN
        SELECT id INTO zone_check FROM zone WHERE zone.name = zonename;
        IF NOT FOUND THEN
                RAISE EXCEPTION 'zone % not found', zonename;
        END IF;

	RETURN QUERY SELECT label FROM zone INNER JOIN label ON zone.id = zone_id WHERE name = zonename;
	RETURN;
END; $$ LANGUAGE plpgsql;
