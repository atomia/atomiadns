CREATE OR REPLACE FUNCTION GetSlavezonesTSIGKeys(
	nameservername varchar,
	out zone_id bigint,
	out zone_name varchar,
	out tsigkey_name varchar
) RETURNS SETOF record AS $$
DECLARE 
	r RECORD;
	nameserver_group_id_var int;
BEGIN
	SELECT nameserver_group.id INTO nameserver_group_id_var FROM nameserver_group
	INNER JOIN nameserver ON nameserver_group.id = nameserver.nameserver_group_id
	WHERE nameserver.name = nameservername;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'nameserver group % not found', nameservername;
	END IF;

	FOR r IN	SELECT domainmetadata.domain_id, domainmetadata.tsigkey_name, slavezone.name AS zone_name FROM domainmetadata
			INNER JOIN slavezone ON domainmetadata.domain_id = slavezone.id
			WHERE domainmetadata.nameserver_group_id = nameserver_group_id_var AND domainmetadata.kind = 'slave'
	LOOP
		zone_id := r.domain_id;
		zone_name := r.zone_name;
		tsigkey_name := r.tsigkey_name;
		RETURN NEXT;
	END LOOP;

	RETURN;
END; $$ LANGUAGE plpgsql;
