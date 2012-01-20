CREATE OR REPLACE FUNCTION GetNameserverGroups(
) RETURNS SETOF varchar AS $$
BEGIN
	RETURN QUERY SELECT name FROM nameserver_group;
	RETURN;
END; $$ LANGUAGE plpgsql;
