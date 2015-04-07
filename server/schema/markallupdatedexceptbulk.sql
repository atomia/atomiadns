CREATE OR REPLACE FUNCTION MarkAllUpdatedExceptBulk (
	zonenames varchar[], 
	change_ids bigint[]
) RETURNS void AS $$
DECLARE
        nameserver_id_var int;
BEGIN
	IF array_lower(zonenames, 1) != array_lower(change_ids, 1) OR array_upper(zonenames, 1) != array_upper(change_ids, 1) THEN
		RAISE EXCEPTION 'number of zones is different than number of changes';
	END IF;

	FOR i IN array_lower(zonenames, 1) .. array_upper(zonenames, 1) LOOP
	        SELECT nameserver_id INTO nameserver_id_var FROM change WHERE zone = zonenames[i] AND id = change_ids[i];
	        IF NOT FOUND THEN
	                RAISE EXCEPTION 'change with id % not found for %', change_ids[i], zonenames[i];
	        END IF;

		DELETE FROM change WHERE id != change_ids[i] AND zone = zonenames[i] AND nameserver_id = nameserver_id_var;
	END LOOP;

END; $$ LANGUAGE plpgsql;
