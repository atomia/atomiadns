CREATE OR REPLACE FUNCTION MarkUpdatedBulk (
	change_ids bigint[],
	cstatus varchar[], 
	cmessage varchar[]
) RETURNS void AS $$
BEGIN
	IF	array_lower(change_ids, 1) != array_lower(cstatus, 1) OR array_upper(change_ids, 1) != array_upper(cstatus, 1) OR
		array_lower(change_ids, 1) != array_lower(cmessage, 1) OR array_upper(change_ids, 1) != array_upper(cmessage, 1) THEN
		RAISE EXCEPTION 'number of changes is different than the number of statuses or number of messages';
	END IF;

	FOR i IN array_lower(change_ids, 1) .. array_upper(change_ids, 1) LOOP
		IF cstatus[i] = 'ERROR' THEN
			UPDATE change SET status = 'ERROR', errormessage = cmessage[i] WHERE id = change_ids[i];
		ELSIF cstatus[i] = 'OK' THEN
			DELETE FROM change WHERE id = change_ids[i];
		ELSE
			RAISE EXCEPTION 'bad changestatus % when updating change with id %', cstatus[i], change_ids[i];
		END IF;
	END LOOP;
END; $$ LANGUAGE plpgsql;
