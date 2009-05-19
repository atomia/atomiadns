CREATE OR REPLACE FUNCTION DeleteNameserver(
	servername varchar
) RETURNS void AS $$
BEGIN
	DELETE FROM change USING nameserver WHERE nameserver_id = nameserver.id AND name = servername;
	DELETE FROM nameserver WHERE name = servername;
END; $$ LANGUAGE plpgsql;
