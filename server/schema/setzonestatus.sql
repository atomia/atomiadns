CREATE OR REPLACE FUNCTION SetZoneStatus(
	zonename varchar,
	zonestatus varchar
) RETURNS void AS $$
DECLARE
	zone_id int;
BEGIN
				SELECT id INTO zone_id FROM zone WHERE name = zonename;
        IF NOT FOUND THEN
                RAISE EXCEPTION 'zone % not found', zonename;
        END IF;

				IF zonestatus != 'active' OR zonestatus != 'suspended' THEN
					RAISE EXCEPTION 'zonestatus % is not allowed', zonestatus;
        END IF;

				UPDATE zone SET status = zonestatus WHERE id = zone_id;

	RETURN;
END; $$ LANGUAGE plpgsql;
