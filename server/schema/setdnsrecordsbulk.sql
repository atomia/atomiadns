CREATE OR REPLACE FUNCTION SetDnsRecordsBulk(
	zonenames varchar[],
	records varchar[][]
) RETURNS void AS $$
BEGIN
	FOR i IN array_lower(zonenames, 1) .. array_upper(zonenames, 1) LOOP
		PERFORM SetDnsRecords(zonenames[i], records);
	END LOOP;
END; $$ LANGUAGE plpgsql;
