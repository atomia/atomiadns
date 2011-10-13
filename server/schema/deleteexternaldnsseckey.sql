CREATE OR REPLACE FUNCTION DeleteExternalDNSSECKey(
	keyid int
) RETURNS void AS $$
DECLARE
        current_status int;
BEGIN
        SELECT id INTO current_status FROM dnssec_external_key WHERE id = keyid;
        IF NOT FOUND THEN
                RAISE EXCEPTION 'key % not found', keyid;
        END IF;

	DELETE FROM dnssec_external_key WHERE id = keyid;

END; $$ LANGUAGE plpgsql;
