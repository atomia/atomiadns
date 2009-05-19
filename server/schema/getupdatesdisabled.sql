CREATE OR REPLACE FUNCTION GetUpdatesDisabled(
) RETURNS varchar AS $$
BEGIN
	RETURN (SELECT disabled FROM updates_disabled);
END; $$ LANGUAGE plpgsql;
