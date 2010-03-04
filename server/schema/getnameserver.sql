CREATE OR REPLACE FUNCTION GetNameserver(
	nameservername varchar
) RETURNS varchar AS $$
DECLARE
        groupname varchar;
BEGIN
        SELECT g.name INTO groupname FROM nameserver n INNER JOIN nameserver_group g ON g.id = n.nameserver_group_id WHERE n.name = nameservername;
        IF NOT FOUND THEN
                RAISE EXCEPTION 'nameserver % not found', nameservername;
        END IF;

	RETURN groupname;
END; $$ LANGUAGE plpgsql;
