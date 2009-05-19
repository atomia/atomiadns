DROP TABLE IF EXISTS record;
DROP TABLE IF EXISTS label;
DROP TABLE IF EXISTS zone;
DROP TABLE IF EXISTS allowed_type;
DROP TYPE IF EXISTS dnsclass;

CREATE TYPE dnsclass AS ENUM('IN', 'CH');

CREATE TABLE allowed_type (
        id SERIAL PRIMARY KEY NOT NULL,
        type VARCHAR(16) UNIQUE NOT NULL,
        synopsis VARCHAR(255) NOT NULL,
        regexp VARCHAR(255) NOT NULL
);

INSERT INTO allowed_type (type, synopsis, regexp) VALUES
('A', 'ipv4address', '^([0-9]+[.]){3}[0-9]+$'),
('MX', 'prio hostname', '^[0-9]+ [a-z0-9][a-z0-9.-]+$'),
('SOA', 'mname rname %serial refresh retry expire minimum', '^[a-z0-9.-]+ [a-z0-9.-]+ %serial ([0-9]+ ){3}[0-9]+$'),
('NS', 'hostname', '^[a-z0-9][a-z0-9.-]+$');

CREATE TABLE zone (
        id SERIAL PRIMARY KEY NOT NULL,
        name VARCHAR(255) NOT NULL UNIQUE CONSTRAINT zone_format CHECK (name ~* '^([a-z0-9_][a-z0-9_-]*)([.][a-z0-9_][a-z0-9_-]*)*$')
);

CREATE TABLE label (
        id SERIAL PRIMARY KEY NOT NULL,
        zone_id INT NOT NULL REFERENCES zone,
        label VARCHAR(255) NOT NULL CONSTRAINT label_format CHECK (label ~* '^(([a-z0-9_][a-z0-9_-]*)([.][a-z0-9_][a-z0-9_-]*)*)|@$'),
	UNIQUE (zone_id, label)
);

CREATE TABLE record (
        id SERIAL PRIMARY KEY NOT NULL,
        label_id INT NOT NULL REFERENCES label,
        class dnsclass NOT NULL,
        type VARCHAR(16) NOT NULL,
        ttl INT NOT NULL CONSTRAINT ttl_not_negative CHECK (ttl >= 0),
        rdata TEXT NOT NULL
);

CREATE OR REPLACE FUNCTION verify_record() RETURNS trigger AS $$
DECLARE
        mysynopsis varchar(255);
        myregexp varchar(255);
BEGIN
        SELECT synopsis, regexp INTO mysynopsis, myregexp FROM allowed_type WHERE type = NEW.type;

        IF NOT FOUND THEN
                RAISE EXCEPTION '% is not an available type', NEW.type;
        ELSIF 0 < (SELECT COUNT(*) FROM record WHERE label_id = NEW.label_id AND class = NEW.class AND type = NEW.type AND ttl != NEW.ttl) THEN
                RAISE EXCEPTION '% is different from existing ttl for this label/class/type triplet', NEW.ttl;
        ELSIF NEW.rdata !~* myregexp THEN
                RAISE EXCEPTION '% isn\'t allowed rdata for %, synopsis is "%"', NEW.rdata, NEW.type, mysynopsis;
        ELSE
                RETURN NEW;
        END IF;
END; $$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER record_constraint AFTER INSERT OR UPDATE
ON record
FOR EACH ROW
EXECUTE PROCEDURE verify_record();

CREATE OR REPLACE FUNCTION verify_zone() RETURNS trigger AS $$
DECLARE
	numsoa int;
	numcorrectsoa int;
	numns int;
	zoneid int;
	labelid int;
BEGIN
	IF TG_TABLE_NAME = 'zone' THEN
		zoneid := NEW.id;
	ELSIF TG_TABLE_NAME = 'label' THEN
		IF TG_OP = 'DELETE' THEN
			zoneid := OLD.zone_id;
		ELSIF TG_OP = 'UPDATE' THEN
			IF NEW.zone_id != OLD.zone_id THEN
				RAISE EXCEPTION 'moving labels cross zones are not supported';
			END IF;

			zoneid := NEW.zone_id;
		ELSE
			zoneid := NEW.zone_id;
		END IF;
	ELSIF TG_TABLE_NAME = 'record' THEN
		IF TG_OP = 'DELETE' THEN
			labelid := OLD.label_id;
		ELSIF TG_OP = 'UPDATE' THEN
			IF NEW.label_id != OLD.label_id THEN
				RAISE EXCEPTION 'moving records cross labels are not supported';
			END IF;

			labelid := NEW.label_id;
		ELSE
			labelid := NEW.label_id;
		END IF;

		SELECT zone_id INTO zoneid FROM label WHERE id = labelid;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'error finding zone_id for inserted record, should not happen';
		END IF;
	ELSE
		RAISE EXCEPTION '% is not a supported table for this trigger. please report this as a bug.', TG_TABLE_NAME;
	END IF;

	SELECT COUNT(NULLIF(type = 'SOA', false)), COUNT(NULLIF(l.label = '@' AND type = 'SOA', false)), COUNT(NULLIF(l.label = '@' AND type = 'NS', false)) INTO numsoa, numcorrectsoa, numns
	FROM label l INNER JOIN record r ON l.id = r.label_id
	WHERE l.zone_id = zoneid;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'error frinding zone_id for update, should not happen';
	END IF;

	IF numsoa != 1 OR numcorrectsoa != 1 THEN
		RAISE EXCEPTION 'zone needs to have exactly one SOA and it should be for \'@\'';
	ELSIF numns < 1 THEN
		RAISE EXCEPTION 'zone needs to have one or more NS-records set for \'@\'';
	ELSE
		RETURN NEW;
	END IF;
END; $$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER record_zonecheck_constraint AFTER INSERT OR UPDATE OR DELETE
ON record
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE PROCEDURE verify_zone();

CREATE CONSTRAINT TRIGGER label_zonecheck_constraint AFTER INSERT OR UPDATE OR DELETE
ON label
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE PROCEDURE verify_zone();

CREATE CONSTRAINT TRIGGER zone_zonecheck_constraint AFTER INSERT OR UPDATE
ON zone
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE PROCEDURE verify_zone();

-- Start of methods

CREATE OR REPLACE FUNCTION CreateZone(
	zonename varchar,
	zonettl int,
	mname varchar,
	rname varchar,
	refresh int,
	retry int,
	expire int,
	minimum bigint,
	nameservers varchar[]
) RETURNS void AS $$
BEGIN
	IF refresh < 0 THEN
		RAISE EXCEPTION 'refresh value of % is out of range (0 .. 2147483647)', refresh;
	ELSIF retry < 0 THEN
		RAISE EXCEPTION 'retry value of % is out of range (0 .. 2147483647)', retry;
	ELSIF expire < 0 THEN
		RAISE EXCEPTION 'expire value of % is out of range (0 .. 2147483647)', expire;
	ELSIF minimum NOT BETWEEN 0 AND 4294967295 THEN 
		RAISE EXCEPTION 'minimum value of % is out of range (0 .. 4294967295)', minimum;
	END IF;

	INSERT INTO zone (name) VALUES (zonename);
	INSERT INTO label (zone_id, label) VALUES (currval('zone_id_seq'), '@');

	INSERT INTO record (label_id, class, type, ttl, rdata)
	VALUES (currval('label_id_seq'), 'IN', 'SOA', zonettl,
		mname || ' ' || rname || ' %serial ' || refresh || ' ' || retry || ' ' || expire || ' ' || minimum);

	FOR i IN array_lower(nameservers, 1) .. array_upper(nameservers, 1) LOOP
		INSERT INTO record (label_id, class, type, ttl, rdata)
		VALUES (currval('label_id_seq'), 'IN', 'NS', zonettl, nameservers[i]);
	END LOOP;

END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION EditZone(
	zonename varchar,
	zonettl int,
	mname varchar,
	rname varchar,
	refresh int,
	retry int,
	expire int,
	minimum bigint,
	nameservers varchar[]
) RETURNS void AS $$
DECLARE
	origin_label_id int;
BEGIN
	IF refresh < 0 THEN
		RAISE EXCEPTION 'refresh value of % is out of range (0 .. 2147483647)', refresh;
	ELSIF retry < 0 THEN
		RAISE EXCEPTION 'retry value of % is out of range (0 .. 2147483647)', retry;
	ELSIF expire < 0 THEN
		RAISE EXCEPTION 'expire value of % is out of range (0 .. 2147483647)', expire;
	ELSIF minimum NOT BETWEEN 0 AND 4294967295 THEN 
		RAISE EXCEPTION 'minimum value of % is out of range (0 .. 4294967295)', minimum;
	END IF;

	SELECT label.id INTO origin_label_id FROM zone INNER JOIN label ON zone.id = zone_id WHERE label = '@' AND zone.name = zonename;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'zone % not found', zonename;
	END IF;

	DELETE FROM record 
	WHERE record.label_id = origin_label_id AND type IN ('NS', 'SOA');

	INSERT INTO record (label_id, class, type, ttl, rdata)
	VALUES (origin_label_id, 'IN', 'SOA', zonettl,
		mname || ' ' || rname || ' %serial ' || refresh || ' ' || retry || ' ' || expire || ' ' || minimum);

	FOR i IN array_lower(nameservers, 1) .. array_upper(nameservers, 1) LOOP
		INSERT INTO record (label_id, class, type, ttl, rdata)
		VALUES (origin_label_id, 'IN', 'NS', zonettl, nameservers[i]);
	END LOOP;

END; $$ LANGUAGE plpgsql;

SELECT CreateZone('sigint.se', 3600, 'ns1.loopia.se.', 'registry.loopia.se.', 10800, 3600, 604800, 86400, ARRAY['ns1.loopia.se', 'ns2.loopia.se']);
INSERT INTO label (zone_id, label) VALUES (1, 'www');
INSERT INTO record (label_id, class, type, ttl, rdata) VALUES (2, 'IN', 'A', 3600, '127.0.0.1');
