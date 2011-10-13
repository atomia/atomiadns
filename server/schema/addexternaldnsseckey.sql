CREATE OR REPLACE FUNCTION AddExternalDNSSECKey(
	k_keydata text
) RETURNS int AS $$
BEGIN
	INSERT INTO dnssec_external_key (keydata) VALUES (k_keydata);
	RETURN currval('dnssec_external_key_id_seq');
END; $$ LANGUAGE plpgsql;
