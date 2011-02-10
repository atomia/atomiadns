CREATE OR REPLACE FUNCTION GetDNSSECKeys(
        out key_id int,
        out key_algorithm algorithmtype,
        out key_keysize int,
        out key_keytype dnsseckeytype,
        out key_activated int,
        out key_keydata text,
        out key_created_at timestamp,
        out key_activated_at timestamp,
        out key_deactivated_at timestamp 
) RETURNS SETOF record AS $$
DECLARE r RECORD;
BEGIN
        FOR r IN        SELECT * FROM dnssec_keyset 
        LOOP
                key_id := r.id;
                key_algorithm := r.algorithm;
                key_keysize := r.keysize;
                key_keytype := r.keytype;
                key_activated := r.activated;
                key_keydata := r.keydata;
                key_created_at := r.created_at;
                key_activated_at := r.activated_at;
                key_deactivated_at := r.deactivated_at;
                RETURN NEXT;
        END LOOP;

        RETURN;
END; $$ LANGUAGE plpgsql;

