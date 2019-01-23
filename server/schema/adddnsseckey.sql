CREATE OR REPLACE FUNCTION AddDNSSECKey(
	k_algorithm varchar,
	k_keysize int,
	k_keytype varchar,
	k_activated int,
	k_keydata text
) RETURNS int AS $$
BEGIN
	IF NOT k_algorithm IN ('RSASHA1', 'RSASHA256', 'RSASHA512', 'ECDSAP256SHA256', 'ECDSAP384SHA384') THEN
		RAISE EXCEPTION 'algorithm % is unknown, we support RSASHA1, RSASHA256, RSASHA512, ECDSAP256SHA256 and ECDSAP384SHA384', k_algorithm;
	ELSIF NOT ((k_algorithm = 'RSASHA512' AND k_keysize BETWEEN 1024 AND 4096) OR (k_algorithm IN ('RSASHA1', 'RSASHA256') AND k_keysize BETWEEN 512 AND 4096) OR (k_algorithm = 'ECDSAP256SHA256' AND k_keysize = 256) OR (k_algorithm = 'ECDSAP384SHA384' AND k_keysize = 384)) THEN
		RAISE EXCEPTION 'unsupported keysize % for algorithm %', k_keysize, k_algorithm;
	ELSIF k_keytype NOT IN ('ZSK', 'KSK') THEN
		RAISE EXCEPTION 'keytype has to be ZSK or KSK';
	ELSIF k_activated = 0 THEN
		INSERT INTO dnssec_keyset (algorithm, keysize, keytype, activated, keydata, created_at, activated_at) VALUES (k_algorithm::algorithmtype, k_keysize, k_keytype::dnsseckeytype, k_activated, k_keydata, CURRENT_TIMESTAMP, NULL);
	ELSIF k_activated = 1 THEN
		INSERT INTO dnssec_keyset (algorithm, keysize, keytype, activated, keydata, created_at, activated_at) VALUES (k_algorithm::algorithmtype, k_keysize, k_keytype::dnsseckeytype, k_activated, k_keydata, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
	ELSE
		RAISE EXCEPTION 'activated should be 0 or 1';
	END IF;

	RETURN currval('dnssec_keyset_id_seq');

END; $$ LANGUAGE plpgsql;
