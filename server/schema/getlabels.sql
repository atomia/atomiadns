CREATE OR REPLACE FUNCTION GetLabels(
	zonename varchar
) RETURNS SETOF varchar AS $$
BEGIN
	RETURN QUERY SELECT label FROM zone INNER JOIN label ON zone.id = zone_id WHERE name = zonename;
	RETURN;
END; $$ LANGUAGE plpgsql;
