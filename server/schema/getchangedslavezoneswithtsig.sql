CREATE OR REPLACE FUNCTION GetChangedSlaveZonesWithTSIG(
	nameservername varchar,
	out change_id bigint,
	out change_name varchar,
	out change_changetime int,
	out change_tsigkeyname varchar
) RETURNS SETOF record AS $$
DECLARE r RECORD;
BEGIN
	FOR r IN	SELECT slavezone_change.id, zone, changetime, domainmetadata.tsigkey_name as tsigkeyname FROM slavezone_change 
			INNER JOIN nameserver ON nameserver_id = nameserver.id
			LEFT JOIN slavezone ON zone = slavezone.name LEFT JOIN domainmetadata ON slavezone.id = domainmetadata.domain_id AND domainmetadata.kind = 'slave'
			WHERE nameserver.name = nameservername AND status = 'PENDING' 
			ORDER BY changetime ASC, slavezone_change.id ASC
	LOOP
		change_id := r.id;
		change_name := r.zone;
		change_changetime := r.changetime;
		change_tsigkeyname := r.tsigkeyname;
		RETURN NEXT;
	END LOOP;

	RETURN;
END; $$ LANGUAGE plpgsql;
