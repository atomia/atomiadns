CREATE OR REPLACE FUNCTION CopyDnsLabelBulk(
	zonename varchar,
	labelname varchar,
	targets varchar[][]
) RETURNS void AS $$
DECLARE
	records varchar[][];
	rowarray varchar[];
	r record;
BEGIN

	FOR r IN	SELECT *
			FROM zone INNER JOIN label ON zone.id = zone_id INNER JOIN record ON label.id = label_id
			WHERE zone.name = zonename AND label = labelname
	LOOP
		rowarray := ARRAY[[r.id::varchar, r.label, r.class::varchar, r.ttl::varchar, r.type, r.rdata]];
		records := records || rowarray;
	END LOOP;

	FOR i IN array_lower(targets, 1) .. array_upper(targets, 1) LOOP

		IF targets[i][1] = zonename AND targets[i][2] = labelname THEN
			RAISE EXCEPTION 'hostname %.% specified both as source and destination', labelname, zonename;
		END IF;

		FOR j IN array_lower(records, 1) .. array_upper(records, 1) LOOP
			records[j][2] := targets[i][2];
		END LOOP;

		DELETE FROM record USING label INNER JOIN zone ON zone.id = zone_id WHERE label_id = label.id AND zone.name = targets[i][1] AND label = targets[i][2];
		PERFORM AddDnsRecords(targets[i][1], records);
		DELETE FROM label USING zone WHERE zone.id = zone_id AND zone.name = targets[i][1] AND NOT EXISTS (SELECT id FROM record WHERE label_id = label.id);

	END LOOP;
END; $$ LANGUAGE plpgsql;
