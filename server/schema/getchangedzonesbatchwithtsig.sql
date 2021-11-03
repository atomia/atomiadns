CREATE OR REPLACE FUNCTION GetChangedZonesBatchWithTSIG(
	nameservername varchar,
	changelimit int,
	out change_id bigint,
	out change_name varchar,
	out change_changetime int,
	out change_tsigkeyname varchar
) RETURNS SETOF record AS $$
DECLARE r RECORD;
BEGIN
	FOR r IN	SELECT res.id, res.zone, res.changetime, domainmetadata.tsigkey_name as tsigkeyname FROM 
			(SELECT MAX(change.id) AS id, change.zone, MAX(changetime) AS changetime FROM change INNER JOIN nameserver ON nameserver_id = nameserver.id 
			WHERE nameserver.name = nameservername AND status = 'PENDING'
			GROUP BY zone
			LIMIT changelimit) AS res
			LEFT JOIN zone ON res.zone = zone.name LEFT JOIN domainmetadata ON zone.id = domainmetadata.domain_id AND domainmetadata.kind = 'master'
	LOOP
		change_id := r.id;
		change_name := r.zone;
		change_changetime := r.changetime;
		change_tsigkeyname := r.tsigkeyname;
		RETURN NEXT;
	END LOOP;

	RETURN;
END; $$ LANGUAGE plpgsql;
