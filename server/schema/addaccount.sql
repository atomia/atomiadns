CREATE OR REPLACE FUNCTION AddAccount(
	email_param varchar,
	hash_param varchar
) RETURNS void AS $$
BEGIN
	INSERT INTO account (email, hash) VALUES (email_param, hash_param);
END; $$ LANGUAGE plpgsql;
