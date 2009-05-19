CREATE OR REPLACE FUNCTION DeleteDnsRecords(
	zonename varchar,
	records varchar[][]
) RETURNS void AS $$
DECLARE
	num_records int;
BEGIN
	FOR i IN array_lower(records, 1) .. array_upper(records, 1) LOOP

		SELECT COUNT(*) INTO num_records FROM zone INNER JOIN label ON zone.id = zone_id INNER JOIN record ON label.id = label_id
		WHERE name = zonename AND record.id = records[i][1]::int;

		IF num_records != 1 THEN
			RAISE EXCEPTION 'record with id % doesn\'t exist in zone %', records[i][1], zonename;
		END IF;

		DELETE FROM record WHERE id = records[i][1]::int;

	END LOOP;

	DELETE FROM label USING zone WHERE zone.id = zone_id AND zone.name = zonename AND NOT EXISTS (SELECT id FROM record WHERE label_id = label.id);

END; $$ LANGUAGE plpgsql;
