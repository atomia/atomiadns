CREATE OR REPLACE FUNCTION MarkSlaveZoneUpdated (
	change_id int,
	cstatus varchar, 
	cmessage varchar 
) RETURNS void AS $$
BEGIN
	IF cstatus = 'ERROR' THEN
		UPDATE slavezone_change SET status = 'ERROR', errormessage = cmessage WHERE id = change_id;
	ELSIF cstatus = 'OK' THEN
		DELETE FROM slavezone_change WHERE id = change_id;
	ELSE
		RAISE EXCEPTION 'bad changestatus % when updating change with id %', cstatus, change_id;
	END IF;
END; $$ LANGUAGE plpgsql;
