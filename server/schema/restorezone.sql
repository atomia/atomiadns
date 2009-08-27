CREATE OR REPLACE FUNCTION RestoreZone(
	zonename varchar,
	records varchar[][]
) RETURNS void AS $$
BEGIN
        DELETE FROM record USING label INNER JOIN zone ON zone_id = zone.id WHERE label_id = label.id AND zone.name = zonename;
        DELETE FROM label USING zone WHERE zone_id = zone.id AND zone.name = zonename;
        DELETE FROM zone WHERE zone.name = zonename;

	INSERT INTO zone (name) VALUES (zonename);
	PERFORM * FROM AddDnsRecords(zonename, records);
END; $$ LANGUAGE plpgsql;
