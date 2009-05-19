CREATE OR REPLACE FUNCTION AddNameserver(
	servername varchar
) RETURNS void AS $$
BEGIN
	INSERT INTO nameserver (name) VALUES (servername);
END; $$ LANGUAGE plpgsql;
