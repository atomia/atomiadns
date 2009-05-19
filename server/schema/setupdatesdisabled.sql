CREATE OR REPLACE FUNCTION SetUpdatesDisabled(
	status int
) RETURNS void AS $$
BEGIN
	UPDATE updates_disabled SET disabled = status;
END; $$ LANGUAGE plpgsql;
