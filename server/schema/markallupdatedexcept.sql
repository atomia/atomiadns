CREATE OR REPLACE FUNCTION MarkAllUpdatedExcept (
	zonearg varchar, 
	change_id bigint
) RETURNS void AS $$
DECLARE
        nameserver_id_var int;
BEGIN
        SELECT nameserver_id INTO nameserver_id_var FROM change WHERE zone = zonearg AND id = change_id;
        IF NOT FOUND THEN
                RAISE EXCEPTION 'change with id % not found for %', change_id, zonearg;
        END IF;

	DELETE FROM change WHERE id != change_id AND zone = zonearg AND nameserver_id = nameserver_id_var;
END; $$ LANGUAGE plpgsql;
