CREATE OR REPLACE FUNCTION AddNameserverGroup(
	groupname varchar
) RETURNS void AS $$
BEGIN
	INSERT INTO nameserver_group (name) VALUES (groupname);
END; $$ LANGUAGE plpgsql;
