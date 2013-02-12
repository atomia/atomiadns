CREATE OR REPLACE FUNCTION AddSlaveZoneAuth(
	account_id_param int,
	zonename varchar,
	master_ip varchar,
	nameserver_group_name varchar,
	tsig_keyname varchar,
	tsig varchar
) RETURNS void AS $$
DECLARE
	nameserver_group_id_var int;
	account_check int;
BEGIN
	SELECT id INTO account_check FROM account WHERE id = account_id_param;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'account with id % not found', account_id_param;
        END IF;

	SELECT nameserver_group.id INTO nameserver_group_id_var FROM nameserver_group WHERE name = nameserver_group_name;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'nameserver group % not found', nameserver_group_name;
	END IF;

	INSERT INTO slavezone (account_id, name, nameserver_group_id, master, tsig_name, tsig_secret) VALUES (account_id_param, zonename, nameserver_group_id_var, master_ip, tsig_keyname, tsig);
END; $$ LANGUAGE plpgsql;
