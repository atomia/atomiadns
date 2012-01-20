CREATE OR REPLACE FUNCTION EditAccount(
	email_param varchar,
	hash_param varchar
) RETURNS void AS $$
DECLARE
    account_id int;
BEGIN
	SELECT id INTO account_id FROM account WHERE email = email_param;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'account with username % not found', email_param;
	END IF;

	UPDATE account SET hash = hash_param WHERE id = account_id;
END; $$ LANGUAGE plpgsql;
