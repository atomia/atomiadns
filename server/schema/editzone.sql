CREATE OR REPLACE FUNCTION EditZone(
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
	origin_label_id int;
	nameserver_group_id_var int;
BEGIN
	IF refresh < 0 THEN
		RAISE EXCEPTION 'refresh value of % is out of range (0 .. 2147483647)', refresh;
	ELSIF retry < 0 THEN
		RAISE EXCEPTION 'retry value of % is out of range (0 .. 2147483647)', retry;
	ELSIF expire < 0 THEN
		RAISE EXCEPTION 'expire value of % is out of range (0 .. 2147483647)', expire;
	ELSIF minimum NOT BETWEEN 0 AND 4294967295 THEN 
		RAISE EXCEPTION 'minimum value of % is out of range (0 .. 4294967295)', minimum;
	END IF;

	SELECT label.id INTO origin_label_id FROM zone INNER JOIN label ON zone.id = zone_id WHERE label = '@' AND zone.name = zonename;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'zone % not found', zonename;
	END IF;

	SELECT nameserver_group.id INTO nameserver_group_id_var FROM nameserver_group WHERE name = nameserver_group_name;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'nameserver group % not found', nameserver_group_name;
	END IF;

	UPDATE zone SET nameserver_group_id = nameserver_group_id_var WHERE name = zonename;

	DELETE FROM record 
	WHERE record.label_id = origin_label_id AND type IN ('NS', 'SOA');

	INSERT INTO record (label_id, class, type, ttl, rdata)
	VALUES (origin_label_id, 'IN', 'SOA', zonettl,
		mname || ' ' || rname || ' %serial ' || refresh || ' ' || retry || ' ' || expire || ' ' || minimum);

	FOR i IN array_lower(nameservers, 1) .. array_upper(nameservers, 1) LOOP
		INSERT INTO record (label_id, class, type, ttl, rdata)
		VALUES (origin_label_id, 'IN', 'NS', zonettl, nameservers[i]);
	END LOOP;

END; $$ LANGUAGE plpgsql;
