CREATE OR REPLACE FUNCTION AddZoneAuth(
	account_id_param int,
	zonename varchar,
	zonettl int,
	mname varchar,
	rname varchar,
	refresh int,
	retry int,
	expire int,
	minimum bigint,
	nameservers varchar[],
	nameserver_group_name varchar
) RETURNS void AS $$
DECLARE
	nameserver_group_id_var int;
	account_check int;
BEGIN
	SELECT id INTO account_check FROM account WHERE id = account_id_param;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'account with id % not found', account_id_param;
        END IF;

	IF refresh < 0 THEN
		RAISE EXCEPTION 'refresh value of % is out of range (0 .. 2147483647)', refresh;
	ELSIF retry < 0 THEN
		RAISE EXCEPTION 'retry value of % is out of range (0 .. 2147483647)', retry;
	ELSIF expire < 0 THEN
		RAISE EXCEPTION 'expire value of % is out of range (0 .. 2147483647)', expire;
	ELSIF minimum NOT BETWEEN 0 AND 4294967295 THEN 
		RAISE EXCEPTION 'minimum value of % is out of range (0 .. 4294967295)', minimum;
	END IF;

	SELECT nameserver_group.id INTO nameserver_group_id_var FROM nameserver_group WHERE name = nameserver_group_name;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'nameserver group % not found', nameserver_group_name;
	END IF;

	INSERT INTO zone (name, nameserver_group_id, account_id) VALUES (zonename, nameserver_group_id_var, account_id_param);
	INSERT INTO label (zone_id, label) VALUES (currval('zone_id_seq'), '@');

	INSERT INTO record (label_id, class, type, ttl, rdata)
	VALUES (currval('label_id_seq'), 'IN', 'SOA', zonettl,
		mname || ' ' || rname || ' %serial ' || refresh || ' ' || retry || ' ' || expire || ' ' || minimum);

	FOR i IN array_lower(nameservers, 1) .. array_upper(nameservers, 1) LOOP
		INSERT INTO record (label_id, class, type, ttl, rdata)
		VALUES (currval('label_id_seq'), 'IN', 'NS', zonettl, nameservers[i]);
	END LOOP;

END; $$ LANGUAGE plpgsql;
