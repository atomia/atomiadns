CREATE OR REPLACE FUNCTION GetExternalDNSSECKeys(
        out key_id int,
        out key_keydata text
) RETURNS SETOF record AS $$
DECLARE r RECORD;
BEGIN
        FOR r IN        SELECT * FROM dnssec_external_key
        LOOP
                key_id := r.id;
                key_keydata := r.keydata;
                RETURN NEXT;
        END LOOP;

        RETURN;
END; $$ LANGUAGE plpgsql;

