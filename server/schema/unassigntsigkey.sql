CREATE OR REPLACE FUNCTION UnassignTSIGKey (
	domain_name varchar
) RETURNS void AS $$
DECLARE
	domainmetadata_id_var bigint;
	domain_id_var bigint;
	kind_var_old varchar := 'TSIG-ALLOW-AXFR';
	kind_var varchar := 'master';
BEGIN
	SELECT zone.id INTO domain_id_var FROM zone WHERE name = domain_name;
	IF NOT FOUND THEN
		kind_var_old := 'AXFR-MASTER-TSIG';
		kind_var := 'slave';
		SELECT slavezone.id INTO domain_id_var FROM slavezone WHERE name = domain_name;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'domain % not found', domain_name;
		END IF;
	END IF;

	SELECT id INTO domainmetadata_id_var FROM domainmetadata WHERE domain_id = domain_id_var AND kind IN (kind_var, kind_var_old);
	IF NOT FOUND THEN
		RAISE EXCEPTION 'domainmetadata for domain % not found', domain_name;
	END IF;

	DELETE FROM domainmetadata WHERE domain_id = domain_id_var AND kind IN (kind_var, kind_var_old);
END; $$ LANGUAGE plpgsql;