CREATE OR REPLACE FUNCTION GetAllowedZoneTransfer(
	out zonename varchar,
	out allowed_ip varchar 
) RETURNS SETOF record AS $$
DECLARE r RECORD;
BEGIN
	FOR r IN SELECT zone, ip FROM allow_zonetransfer
	LOOP
		zonename := r.zone;
		allowed_ip := r.ip;
		RETURN NEXT;
	END LOOP;

	RETURN;
END; $$ LANGUAGE plpgsql;
