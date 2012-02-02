CREATE OR REPLACE FUNCTION RestoreZoneAuth(
	account_id_param int,
	zonename varchar,
	nameserver_group_name varchar,
	records varchar[][]
) RETURNS void AS $$
DECLARE
	nameserver_group_id_var int;
	account_check int;
BEGIN
	SELECT id INTO account_check FROM account WHERE id = account_id_param;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'account with id % not found', account_id_param;
	END IF;

	SELECT nameserver_group.id INTO nameserver_group_id_var FROM nameserver_group WHERE name = nameserver_group_name;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'nameserver group % not found', nameserver_group_name;
	END IF;

        DELETE FROM record USING label INNER JOIN zone ON zone_id = zone.id WHERE label_id = label.id AND zone.name = zonename;
        DELETE FROM label USING zone WHERE zone_id = zone.id AND zone.name = zonename;
        DELETE FROM zone WHERE zone.name = zonename;

	INSERT INTO zone (name, nameserver_group_id, account_id) VALUES (zonename, nameserver_group_id_var, account_id_param);
	PERFORM * FROM AddDnsRecords(zonename, records);
END; $$ LANGUAGE plpgsql;
