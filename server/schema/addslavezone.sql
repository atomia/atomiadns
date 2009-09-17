CREATE OR REPLACE FUNCTION AddSlaveZone(
	zonename varchar,
	master_ip varchar,
	nameserver_group_name varchar
) RETURNS void AS $$
DECLARE
	nameserver_group_id_var int;
BEGIN
	SELECT nameserver_group.id INTO nameserver_group_id_var FROM nameserver_group WHERE name = nameserver_group_name;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'nameserver group % not found', nameserver_group_name;
	END IF;

	INSERT INTO slavezone (name, nameserver_group_id, master) VALUES (zonename, nameserver_group_id_var, master_ip);
END; $$ LANGUAGE plpgsql;
