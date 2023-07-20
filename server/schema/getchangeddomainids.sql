CREATE OR REPLACE FUNCTION GetChangedDomainIDs(
	nameservername varchar,
	out change_id bigint,
	out change_domain_id varchar,
	out change_changetime int
) RETURNS SETOF record AS $$
DECLARE
	r RECORD;
    table_exists BOOLEAN;
    sql_query TEXT;
BEGIN
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE  table_schema = 'public'
        AND    table_name   = 'domainmetadata_change'
    ) INTO table_exists;

    IF table_exists THEN
        sql_query := 'SELECT domainmetadata_change.id, domain_id, changetime FROM domainmetadata_change INNER JOIN nameserver ON nameserver_id = nameserver.id WHERE nameserver.name = $1 AND status = ''PENDING'' ORDER BY changetime ASC, domainmetadata_change.id ASC';
        
        FOR r IN EXECUTE sql_query USING nameservername
        LOOP
		    change_id := r.id;
		    change_domain_id := r.domain_id;
		    change_changetime := r.changetime;
		    RETURN NEXT;
	    END LOOP;
    ELSE
        RAISE NOTICE 'Table domainmetadata_change does not exist.';
    END IF;

	RETURN;
END; $$ LANGUAGE plpgsql;
