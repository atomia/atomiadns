CREATE OR REPLACE FUNCTION Noop(
) RETURNS varchar AS $$
BEGIN
	RETURN 'Nothing happens.';
END; $$ LANGUAGE plpgsql;
