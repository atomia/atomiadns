CREATE OR REPLACE FUNCTION AuthorizeSlaveZones(
	zonenames varchar[],
	account_id_to_auth int
) RETURNS int AS $$
DECLARE
	account_check INT;
BEGIN

	FOR i IN array_lower(zonenames, 1) .. array_upper(zonenames, 1) LOOP
	        SELECT account_id INTO account_check FROM slavezone WHERE slavezone.name = zonenames[i];
	        IF NOT FOUND THEN
			RETURN 0;
		ELSIF account_check IS NULL THEN
			return 0;
		ELSIF account_check <> account_id_to_auth THEN
			return 0;
	        END IF;
	END LOOP;

	RETURN 1;
END; $$ LANGUAGE plpgsql;
