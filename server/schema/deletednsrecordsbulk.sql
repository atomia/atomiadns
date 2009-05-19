CREATE OR REPLACE FUNCTION DeleteDnsRecordsBulk(
	zones varchar[],
	records varchar[][]
) RETURNS void AS $$
BEGIN

	FOR i IN array_lower(zones, 1) .. array_upper(zones, 1) LOOP

		FOR j IN array_lower(records, 1) .. array_upper(records, 1) LOOP
			DELETE FROM record USING label INNER JOIN zone ON zone.id = zone_id WHERE label_id = label.id AND zone.name = zones[i]
			AND label = records[j][2] AND class = records[j][3]::dnsclass AND ttl = records[j][4]::int
			AND type = records[j][5] AND rdata = records[j][6];
		END LOOP;

		DELETE FROM label USING zone WHERE zone.id = zone_id AND zone.name = zones[i] AND NOT EXISTS (SELECT id FROM record WHERE label_id = label.id);

	END LOOP;
END; $$ LANGUAGE plpgsql;
