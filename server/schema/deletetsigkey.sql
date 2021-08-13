CREATE OR REPLACE FUNCTION DeleteTSIGKey (
	tsig_key_name varchar
) RETURNS void AS $$
DECLARE
	tsig_id_var bigint;
BEGIN
	SELECT id INTO tsig_id_var FROM tsigkey WHERE name = tsig_key_name;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'tsig key % not found', tsig_key_name;
	END IF;

	DELETE FROM tsigkey WHERE name = tsig_key_name;
END; $$ LANGUAGE plpgsql;
