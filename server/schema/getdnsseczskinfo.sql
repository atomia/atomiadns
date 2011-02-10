CREATE OR REPLACE FUNCTION GetDNSSECZSKInfo(
        out zskinfo_id int,
        out zskinfo_activated int,
        out zskinfo_created_at timestamp,
        out zskinfo_activated_at timestamp,
        out zskinfo_deactivated_at timestamp,
	out zskinfo_created_ago_seconds int,
	out zskinfo_deactivated_ago_seconds int,
	out zskinfo_max_ttl int
) RETURNS SETOF record AS $$
DECLARE r RECORD;
BEGIN
        FOR r IN        SELECT	id, activated, created_at, activated_at, deactivated_at,
				EXTRACT(epoch FROM current_timestamp-created_at)::int AS created_ago_seconds, EXTRACT(epoch FROM current_timestamp-deactivated_at)::int AS deactivated_ago_seconds,
				(SELECT MAX(ttl) FROM record) AS max_ttl
			FROM dnssec_keyset WHERE keytype = 'ZSK'
        LOOP
                zskinfo_id := r.id;
                zskinfo_activated := r.activated;
                zskinfo_created_at := r.created_at;
                zskinfo_activated_at := r.activated_at;
                zskinfo_deactivated_at := r.deactivated_at;
		zskinfo_created_ago_seconds := r.created_ago_seconds;
		zskinfo_deactivated_ago_seconds := r.deactivated_ago_seconds;
		zskinfo_max_ttl := r.max_ttl;
                RETURN NEXT;
        END LOOP;

        RETURN;
END; $$ LANGUAGE plpgsql;

