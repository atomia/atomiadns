CREATE OR REPLACE FUNCTION GetChangedDomainIDs(
	nameservername varchar,
	out change_id bigint,
	out change_domain_id varchar,
	out change_changetime int
) RETURNS SETOF record AS $$
DECLARE r RECORD;
BEGIN
	FOR r IN	SELECT domainmetadata_change.id, domain_id, changetime FROM domainmetadata_change INNER JOIN nameserver ON nameserver_id = nameserver.id
			WHERE nameserver.name = nameservername AND status = 'PENDING' ORDER BY changetime ASC
	LOOP
		change_id := r.id;
		change_domain_id := r.domain_id;
		change_changetime := r.changetime;
		RETURN NEXT;
	END LOOP;

	RETURN;
END; $$ LANGUAGE plpgsql;
