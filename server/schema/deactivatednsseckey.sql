CREATE OR REPLACE FUNCTION DeactivateDNSSECKey(
	keyid int
) RETURNS void AS $$
DECLARE
        current_status int;
BEGIN
        SELECT activated INTO current_status FROM dnssec_keyset WHERE id = keyid;
        IF NOT FOUND THEN
                RAISE EXCEPTION 'key % not found', keyid;
	ELSIF current_status = 0 THEN
		RAISE EXCEPTION 'key % already deactivated', keyid;
        END IF;

	UPDATE dnssec_keyset SET activated = 0, deactivated_at = CURRENT_TIMESTAMP WHERE id = keyid;

END; $$ LANGUAGE plpgsql;
