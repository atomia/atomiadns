CREATE OR REPLACE FUNCTION MarkDomainMetaDataUpdated (
	change_id bigint,
	cstatus varchar, 
	cmessage varchar 
) RETURNS void AS $$
BEGIN
	IF cstatus = 'ERROR' THEN
		UPDATE domainmetadata_change SET status = 'ERROR', errormessage = cmessage WHERE id = change_id;
	ELSIF cstatus = 'OK' THEN
		DELETE FROM domainmetadata_change WHERE id = change_id;
	ELSE
		RAISE EXCEPTION 'bad changestatus % when updating change with id %', cstatus, change_id;
	END IF;
END; $$ LANGUAGE plpgsql;
