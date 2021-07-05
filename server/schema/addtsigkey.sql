CREATE OR REPLACE FUNCTION AddTSIGKey(
	tsig_name varchar,
	tsig_secret varchar,
	tsig_algorithm varchar,
	nameserver_group_name varchar
) RETURNS void AS $$
DECLARE
	nameserver_group_id_var int;
BEGIN
	SELECT nameserver_group.id INTO nameserver_group_id_var FROM nameserver_group WHERE name = nameserver_group_name;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'nameserver group % not found', nameserver_group_name;
	END IF;

	INSERT INTO tsigkey (nameserver_group_id, name, secret, algorithm) VALUES (nameserver_group_id_var, tsig_name, tsig_secret, tsig_algorithm);
END; $$ LANGUAGE plpgsql;
