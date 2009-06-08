CREATE OR REPLACE FUNCTION RestoreZone(
	zonename varchar,
	records varchar[][]
) RETURNS void AS $$
BEGIN
	DELETE FROM record USING label INNER JOIN zone ON zone.id = zone_id WHERE label_id = label.id AND zone.name = zonename;
	PERFORM * FROM AddDnsRecords(zonename, records);
	DELETE FROM label USING zone WHERE zone.id = zone_id AND zone.name = zonename AND NOT EXISTS (SELECT id FROM record WHERE label_id = label.id);
END; $$ LANGUAGE plpgsql;
