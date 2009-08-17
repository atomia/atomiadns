CREATE OR REPLACE FUNCTION GetZone(
	zonename varchar,
	out record_id int,
	out record_label varchar,
	out record_class dnsclass,
	out record_ttl int,
	out record_type varchar,
	out record_rdata varchar
) RETURNS SETOF record AS $$
DECLARE
	r RECORD;
	zone_check INT;
BEGIN
        SELECT id INTO zone_check FROM zone WHERE zone.name = zonename;
        IF NOT FOUND THEN
                RAISE EXCEPTION 'zone % not found', zonename;
        END IF;

	FOR r IN	SELECT record.id, label, class, ttl, type, rdata
			FROM zone INNER JOIN label ON zone.id = zone_id INNER JOIN record ON label.id = label_id
			WHERE zone.name = zonename
	LOOP
		record_id := r.id;
		record_label := r.label;
		record_class := r.class;
		record_ttl := r.ttl;
		record_type := r.type;
		record_rdata := r.rdata;
		RETURN NEXT;
	END LOOP;

	RETURN;
END; $$ LANGUAGE plpgsql;
