CREATE OR REPLACE FUNCTION SetNameserverGroup(
	zonename varchar,
	groupname varchar
) RETURNS void AS $$
DECLARE
	zone_check int;
	nameserver_group_id_var int;
BEGIN
	SELECT id INTO zone_check FROM zone WHERE zone.name = zonename;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'zone % not found', zonename;
	END IF;

	SELECT nameserver_group.id INTO nameserver_group_id_var FROM nameserver_group WHERE name = groupname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'nameserver group % not found', groupname;
	END IF;

	UPDATE zone SET nameserver_group_id = nameserver_group_id_var WHERE id = zone_check;
END; $$ LANGUAGE plpgsql;
