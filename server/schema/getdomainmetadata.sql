CREATE OR REPLACE FUNCTION GetDomainMetaData(
	domainid varchar,
	out record_domain_id varchar,
	out record_kind varchar,
	out record_tsigkey_name varchar
) RETURNS SETOF record AS $$
DECLARE
	r RECORD;
	domain_id_check INT;
BEGIN
        SELECT id INTO domain_id_check FROM domainmetadata WHERE id = CAST(domainid AS INT);
        IF NOT FOUND THEN
                RAISE EXCEPTION 'Domain id % not found', domainid;
        END IF;

	FOR r IN	SELECT domain_id, kind, tsigkey_name FROM domainmetadata WHERE id = CAST(domainid AS INT)
	LOOP
		record_domain_id := r.domain_id;
		record_kind := r.kind;
		record_tsigkey_name := r.tsigkey_name;
		RETURN NEXT;
	END LOOP;

	RETURN;
END; $$ LANGUAGE plpgsql;