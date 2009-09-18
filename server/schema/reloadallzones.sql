CREATE OR REPLACE FUNCTION ReloadAllZones () RETURNS void AS $$
BEGIN
	INSERT INTO change (nameserver_id, zone)
	SELECT nameserver.id, zone.name FROM nameserver, zone WHERE nameserver.nameserver_group_id = zone.nameserver_group_id;
END; $$ LANGUAGE plpgsql;
