CREATE OR REPLACE FUNCTION DeleteDNSSECKey(
	keyid int
) RETURNS void AS $$
DECLARE
        current_status int;
BEGIN
        SELECT activated INTO current_status FROM dnssec_keyset WHERE id = keyid;
        IF NOT FOUND THEN
                RAISE EXCEPTION 'key % not found', keyid;
        END IF;

	DELETE FROM dnssec_keyset WHERE id = keyid;

END; $$ LANGUAGE plpgsql;
