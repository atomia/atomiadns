CREATE OR REPLACE FUNCTION AllowZoneTransfer(
	zonename varchar, 
	allowed_ip varchar 
) RETURNS void AS $$
BEGIN
	INSERT INTO allow_zonetransfer (zone, ip) VALUES (zonename, allowed_ip);
END; $$ LANGUAGE plpgsql;
