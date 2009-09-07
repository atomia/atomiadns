CREATE OR REPLACE FUNCTION GetNameserverGroup(
	zonename varchar
) RETURNS varchar AS $$
DECLARE
        groupname varchar;
BEGIN
        SELECT g.name INTO groupname FROM zone z INNER JOIN nameserver_group g ON g.id = z.nameserver_group_id WHERE z.name = zonename;
        IF NOT FOUND THEN
                RAISE EXCEPTION 'zone % not found', zonename;
        END IF;

	RETURN groupname;
END; $$ LANGUAGE plpgsql;
