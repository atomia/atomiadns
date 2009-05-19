CREATE OR REPLACE FUNCTION AddZone(
	zonename varchar,
	zonettl int,
	mname varchar,
	rname varchar,
	refresh int,
	retry int,
	expire int,
	minimum bigint,
	nameservers varchar[]
) RETURNS void AS $$
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

	INSERT INTO zone (name) VALUES (zonename);
	INSERT INTO label (zone_id, label) VALUES (currval('zone_id_seq'), '@');

	INSERT INTO record (label_id, class, type, ttl, rdata)
	VALUES (currval('label_id_seq'), 'IN', 'SOA', zonettl,
		mname || ' ' || rname || ' %serial ' || refresh || ' ' || retry || ' ' || expire || ' ' || minimum);

	FOR i IN array_lower(nameservers, 1) .. array_upper(nameservers, 1) LOOP
		INSERT INTO record (label_id, class, type, ttl, rdata)
		VALUES (currval('label_id_seq'), 'IN', 'NS', zonettl, nameservers[i]);
	END LOOP;

END; $$ LANGUAGE plpgsql;
