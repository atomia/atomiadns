CREATE OR REPLACE FUNCTION ReloadAllZones () RETURNS void AS $$
BEGIN
	INSERT INTO change (nameserver_id, zone)
	SELECT nameserver.id, zone.name FROM nameserver, zone;
END; $$ LANGUAGE plpgsql;
