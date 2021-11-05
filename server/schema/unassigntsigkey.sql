CREATE OR REPLACE FUNCTION UnassignTSIGKey (
	domain_name varchar
) RETURNS void AS $$
DECLARE
	domainmetadata_id_var bigint;
	domain_id_master_var bigint;
	domain_id_slave_var bigint;
	kind_var varchar := 'master';
BEGIN
	SELECT zone.id INTO domain_id_master_var FROM zone WHERE name = domain_name;
	SELECT slavezone.id INTO domain_id_slave_var FROM slavezone WHERE name = domain_name;
	IF domain_id_master_var IS NULL OR domain_id_slave_var IS NULL THEN
		RAISE EXCEPTION 'domain % not found', domain_name;
	END IF;

	SELECT id INTO domainmetadata_id_var FROM domainmetadata WHERE domain_id = domain_id_master_var AND kind IN ('master', 'TSIG-ALLOW-AXFR');
	IF NOT FOUND THEN
		kind_var := 'slave';
		SELECT id INTO domainmetadata_id_var FROM domainmetadata WHERE domain_id = domain_id_slave_var AND kind IN ('slave', 'AXFR-MASTER-TSIG');
		IF NOT FOUND THEN
			RAISE EXCEPTION 'domainmetadata for domain % not found', domain_name;
		END IF;
	END IF;

	IF kind_var = 'master' THEN
		DELETE FROM domainmetadata WHERE domain_id = domain_id_master_var AND kind IN ('master', 'TSIG-ALLOW-AXFR');
	ELSE
		DELETE FROM domainmetadata WHERE domain_id = domain_id_slave_var AND kind IN ('slave', 'AXFR-MASTER-TSIG');
	END IF;
END; $$ LANGUAGE plpgsql;