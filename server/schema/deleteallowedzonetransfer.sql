CREATE OR REPLACE FUNCTION DeleteAllowedZoneTransfer(
	zonename varchar, 
	allowed_ip varchar 
) RETURNS void AS $$
BEGIN
	DELETE FROM allow_zonetransfer WHERE zone = zonename AND ip = allowed_ip;
END; $$ LANGUAGE plpgsql;
