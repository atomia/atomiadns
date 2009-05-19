CREATE OR REPLACE FUNCTION CopyDnsZoneBulk(
	zonename varchar,
	targets varchar[]
) RETURNS void AS $$
DECLARE
	records varchar[][];
	rowarray varchar[];
	r record;
BEGIN

	FOR r IN	SELECT *
			FROM zone INNER JOIN label ON zone.id = zone_id INNER JOIN record ON label.id = label_id
			WHERE zone.name = zonename
	LOOP
		rowarray := ARRAY[[r.id::varchar, r.label, r.class::varchar, r.ttl::varchar, r.type, r.rdata]];
		records := records || rowarray;
	END LOOP;

	FOR i IN array_lower(targets, 1) .. array_upper(targets, 1) LOOP

		IF targets[i] = zonename THEN
			RAISE EXCEPTION 'zone % specified both as source and destination', zonename;
		END IF;

		PERFORM RestoreZone(targets[i], records);

	END LOOP;
END; $$ LANGUAGE plpgsql;
