CREATE OR REPLACE FUNCTION FindZones (
	email_param varchar,
	pattern_param varchar,
	count_param int,
	offset_param int,
	out zone_name varchar,
	out zone_total varchar
) RETURNS SETOF record AS $$
DECLARE
	r RECORD;
	total_var int;
BEGIN
	SELECT COUNT(*) INTO total_var FROM account a INNER JOIN zone z ON a.id = z.account_id WHERE a.email = email_param AND z.name LIKE pattern_param;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'error retrieving number of zones matching a search';
	END IF;

	FOR r IN	SELECT z.name
			FROM account a INNER JOIN zone z ON a.id = z.account_id
			WHERE a.email = email_param AND z.name LIKE pattern_param
			ORDER BY z.name LIMIT count_param OFFSET offset_param
	LOOP
		zone_name := r.name;
		zone_total := total_var;
		RETURN NEXT;
	END LOOP;

	RETURN;
END; $$ LANGUAGE plpgsql;
