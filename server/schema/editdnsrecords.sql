CREATE OR REPLACE FUNCTION EditDnsRecords(
	zonename varchar,
	records varchar[][]
) RETURNS void AS $$
DECLARE
	record_id int;
	old_record_label_id int;
	new_record_label_id int;
	record_zone_id int;
	num_records int;
BEGIN
	FOR i IN array_lower(records, 1) .. array_upper(records, 1) LOOP

		SELECT id INTO record_zone_id FROM zone WHERE name = zonename;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'zone % not found', zonename;
		END IF;

		SELECT label_id INTO old_record_label_id FROM zone INNER JOIN label ON zone.id = zone_id INNER JOIN record ON label.id = label_id
		WHERE name = zonename AND record.id = records[i][1]::int;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'record with id % doesn\'t exist in zone %', records[i][1], zonename;
		END IF;

		SELECT label.id INTO new_record_label_id FROM zone INNER JOIN label ON zone.id = zone_id WHERE name = zonename AND label = records[i][2];
		IF NOT FOUND THEN
			INSERT INTO label (zone_id, label) VALUES (record_zone_id, records[i][2]);
			new_record_label_id := currval('label_id_seq');
		END IF;

		UPDATE record SET
			label_id = new_record_label_id,
			ttl = records[i][4]::int,
			class = records[i][3]::dnsclass,
			type = records[i][5],
			rdata = records[i][6]
		WHERE id = records[i][1]::int;

		IF new_record_label_id != old_record_label_id THEN
			SELECT COUNT(*) INTO num_records FROM label INNER JOIN record ON label.id = label_id WHERE label.id = old_record_label_id;
			IF num_records = 0 THEN
				DELETE FROM label WHERE id = old_record_label_id;
			END IF;
		END IF;
	END LOOP;
END; $$ LANGUAGE plpgsql;
