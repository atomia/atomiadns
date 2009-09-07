CREATE OR REPLACE FUNCTION RestoreZone(
	zonename varchar,
	nameserver_group_name varchar,
	records varchar[][]
) RETURNS void AS $$
DECLARE
	nameserver_group_id_var int;
BEGIN
	SELECT nameserver_group.id INTO nameserver_group_id_var FROM nameserver_group WHERE name = nameserver_group_name;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'nameserver group % not found', nameserver_group_name;
	END IF;

        DELETE FROM record USING label INNER JOIN zone ON zone_id = zone.id WHERE label_id = label.id AND zone.name = zonename;
        DELETE FROM label USING zone WHERE zone_id = zone.id AND zone.name = zonename;
        DELETE FROM zone WHERE zone.name = zonename;

	INSERT INTO zone (name, nameserver_group_id) VALUES (zonename, nameserver_group_id_var);
	PERFORM * FROM AddDnsRecords(zonename, records);
END; $$ LANGUAGE plpgsql;
