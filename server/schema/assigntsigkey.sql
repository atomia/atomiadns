CREATE OR REPLACE FUNCTION AssignTSIGKey(
	domain varchar,
	tsigkey_name varchar,
	nameserver_group_name varchar
) RETURNS void AS $$
DECLARE
	nameserver_group_id_var int;
	domain_id_var int;
	kind_var varchar := 'master';
BEGIN
	SELECT nameserver_group.id INTO nameserver_group_id_var FROM nameserver_group WHERE name = nameserver_group_name;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'nameserver group % not found', nameserver_group_name;
	END IF;

	SELECT zone.id INTO domain_id_var FROM zone WHERE name = domain;
	IF NOT FOUND THEN
		kind_var := 'slave';
		SELECT slavezone.id INTO domain_id_var FROM slavezone WHERE name = domain;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'domain % not found', domain;
		END IF;
	END IF;

	INSERT INTO domainmetadata (nameserver_group_id, domain_id, kind, tsigkey_name) VALUES (nameserver_group_id_var, domain_id_var, kind_var, tsigkey_name);
END; $$ LANGUAGE plpgsql;
