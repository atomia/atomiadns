CREATE OR REPLACE FUNCTION DeleteNameserverGroup(
	groupname varchar
) RETURNS void AS $$
DECLARE
	nameserver_group_id_var int;
BEGIN
	SELECT nameserver_group.id INTO nameserver_group_id_var FROM nameserver_group WHERE name = groupname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'nameserver group % not found', groupname;
	END IF;

	DELETE FROM nameserver_group WHERE id = nameserver_group_id_var;
END; $$ LANGUAGE plpgsql;
