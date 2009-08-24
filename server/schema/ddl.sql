DROP TABLE IF EXISTS record;
DROP TABLE IF EXISTS label;
DROP TABLE IF EXISTS zone;
DROP TABLE IF EXISTS allowed_type;
DROP TABLE IF EXISTS change;
DROP TABLE IF EXISTS nameserver;
DROP TABLE IF EXISTS updates_disabled;

CREATE TYPE dnsclass AS ENUM('IN', 'CH');
CREATE TYPE changetype AS ENUM('PENDING', 'ERROR', 'OK');

CREATE TABLE allowed_type (
        id SERIAL PRIMARY KEY NOT NULL,
        type VARCHAR(16) UNIQUE NOT NULL,
        synopsis VARCHAR(255) NOT NULL,
        regexp VARCHAR(255) NOT NULL
);

CREATE TABLE updates_disabled (
	disabled INT
);

INSERT INTO updates_disabled (disabled) VALUES (0);

CREATE TABLE atomiadns_schemaversion (
	version INT
);

INSERT INTO atomiadns_schemaversion (version) VALUES (8);

INSERT INTO allowed_type (type, synopsis, regexp) VALUES
('A', 'ipv4address', '^([0-9]+[.]){3}[0-9]+$'),
('AAAA', 'ipv6address', '^[a-z0-9]([a-z0-9]{0,4}:)+(%[a-z0-9])?$'),
('AFSDB', 'subtype hostname', '^[0-9]+ [a-z0-9][a-z0-9.-]+$'),
('CERT', 'type keytag algorithm certificate', '^[0-9]+ [0-9]+ [0-9]+ [A-Za-z0-9+/=]+$'),
('CNAME', 'hostname', '^[a-z0-9][a-z0-9.-]+$'),
('DNAME', 'domain', '^.+$'),
('DNSKEY', 'flag protocol algorithm publickey', '^[0-9]+ [0-9]+ [0-9]+ [A-Za-z0-9+/=]+$'),
('DS', 'keytag algorithm digesttype digest', '^[0-9]+ [0-9]+ [0-9]+ [A-Za-z0-9+/=]+$'),
('HIP', 'pk-algorithm base16-encoded-hit base64-encoded-public-key [rendezvous-server ..]', '^[0-9]+ [A-F0-9]+ [A-Za-z0-9+/=]+( .*)?$'),
('IPSECKEY', 'precedence gateway-type algorithm gateway [base64-encoded-public-key]', '^[0-9]+ [0-9]+ [0-9]+ [a-z0-9][a-z0-9.-]+( [A-Za-z0-9+/=]+)?$'),
('LOC', 'd1 [m1 [s1]] N|S d2 [m2 [s2]] E|W alt [siz [hp [vp]]]', '^[0-9]{1,2}( [0-9]{1,2}?( [0-9]{1,2}([.][0-9]{1,3})?)?)? [NS] [0-9]{1,3}( [0-9]{1,2}?( [0-9]{1,2}([.][0-9]{1,3})?)?)? [EW] -?[0-9.]+m?( [0-9.]+m?){0,3}$'),
('MX', 'prio hostname', '^[0-9]+ [a-z0-9][a-z0-9.-]+$'),
('NAPTR', 'order pref flags service regexp_without_backslash replacement', '^[0-9]+ [0-9]+ "[^"]*" "[^"]*" "[^"]* ([a-z0-9][a-z0-9.-]+)?[.]$'),
('NS', 'hostname', '^[a-z0-9][a-z0-9.-]+$'),
('NSEC', 'hostname type [type ..]', '^[a-z0-9][a-z0-9.-]+ [A-Z0-9]+( [A-Z0-9]+)*$'),
('NSEC3', 'algorithm flags iterations salt next type [.. type]', '^[0-9]+ [0-9]+ [0-9]+ (-|[A-F0-9]+) [A-Z2-7]+ [A-Z0-9]+( [A-Z0-9]+)*$'),
('NSEC3PARAM', 'algorithm flags iterations salt', '^[0-9]+ [0-9]+ [0-9]+ (-|[A-F0-9]+)$'),
('PTR', 'hostname', '^[a-z0-9][a-z0-9.-]+$'),
('RRSIG', 'type algorithm labels origttl expiration keytag signer signature', '^[A-Z0-9]+ [0-9]+ [0-9]+ [0-9]+ ([0-9]{1,10}|[0-9]{14}) [0-9]+ [a-z0-9][a-z0-9.-]+ [A-Za-z0-9+/=]+$'),
('SOA', 'mname rname %serial refresh retry expire minimum', '^[a-z0-9.-]+ [a-z0-9.-]+ %serial ([0-9]+ ){3}[0-9]+$'),
('SPF', 'spfstring', '^"v=spf[0-9][^"]*"$'),
('SRV', 'prio weight port target', '^[0-9]+ [0-9]+ [0-9]+ [a-z0-9][a-z0-9.-]+$'),
('SSHFP', 'algorithm fingerprinttype fingerprint', '^[0-9]+ [0-9]+ [0-9A-F]+$'),
('TXT', 'quotedstring', '^"[^"]*"$');

CREATE TABLE nameserver (
        id SERIAL PRIMARY KEY NOT NULL,
        name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE change (
        id SERIAL PRIMARY KEY NOT NULL,
        nameserver_id INT NOT NULL REFERENCES nameserver,
        zone VARCHAR(255) NOT NULL,
	status changetype NOT NULL DEFAULT 'PENDING',
	errormessage TEXT NULL,
	changetime INT NOT NULL DEFAULT EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)
);

CREATE TABLE zone (
        id SERIAL PRIMARY KEY NOT NULL,
        name VARCHAR(255) NOT NULL UNIQUE CONSTRAINT zone_format CHECK (name ~* '^([a-z0-9_][a-z0-9_-]*)([.][a-z0-9_][a-z0-9_-]*)*$')
);

CREATE TABLE label (
        id SERIAL PRIMARY KEY NOT NULL,
        zone_id INT NOT NULL REFERENCES zone,
        label VARCHAR(255) NOT NULL CONSTRAINT label_format CHECK (label ~* '^(([a-z0-9_][a-z0-9_-]*)([.][a-z0-9_][a-z0-9_-]*)*)|[@*]$'),
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

CREATE INDEX record_label_idx ON record(label_id);

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
        ELSIF NEW.type = 'CNAME' AND 0 < (SELECT COUNT(*) FROM record WHERE label_id = NEW.label_id AND class = NEW.class AND id != NEW.id) THEN
                RAISE EXCEPTION 'other records exist for this label, and CNAME is not allowed with other data'; 
        ELSIF NEW.type != 'CNAME' AND 0 < (SELECT COUNT(*) FROM record WHERE label_id = NEW.label_id AND class = NEW.class AND type = 'CNAME') THEN
                RAISE EXCEPTION 'CNAME exists for this label and CNAME is not allowed with other data'; 
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
	emptylabels int;
BEGIN
	IF TG_TABLE_NAME = 'zone' THEN
		IF TG_OP = 'DELETE' THEN
			INSERT INTO change (nameserver_id, zone)
			SELECT nameserver.id, OLD.name FROM nameserver;
			RETURN OLD;
		ELSE
			zoneid := NEW.id;
		END IF;
	ELSIF TG_TABLE_NAME = 'label' THEN
		IF TG_OP = 'DELETE' THEN
			SELECT id INTO zoneid FROM zone WHERE id = OLD.zone_id;
			IF NOT FOUND THEN
				-- Removing complete zone, allow the labels to be removed regardless
				RETURN OLD;
			END IF;
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
			IF TG_OP = 'DELETE' THEN
				-- Removing zone record together with its label, we verify for
				-- the label instead, since we can't know zone_id here
				RETURN OLD;
			ELSE
				RAISE EXCEPTION 'error finding zone_id for inserted record, should not happen';
			END IF;
		END IF;
	ELSE
		RAISE EXCEPTION '% is not a supported table for this trigger. please report this as a bug.', TG_TABLE_NAME;
	END IF;

	SELECT COUNT(NULLIF(type = 'SOA', false)), COUNT(NULLIF(l.label = '@' AND type = 'SOA', false)), COUNT(NULLIF(l.label = '@' AND type = 'NS', false)) INTO numsoa, numcorrectsoa, numns
	FROM label l INNER JOIN record r ON l.id = r.label_id
	WHERE l.zone_id = zoneid;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'error frinding number of soas and number of ns-records, should not happen';
	END IF;

	SELECT COUNT(*) INTO emptylabels
	FROM label l LEFT JOIN record r ON l.id = r.label_id
	WHERE l.zone_id = zoneid AND r.id IS NULL;

	IF numsoa != 1 OR numcorrectsoa != 1 THEN
		RAISE EXCEPTION 'zone needs to have exactly one SOA and it should be for \'@\'';
	ELSIF numns < 1 THEN
		RAISE EXCEPTION 'zone needs to have one or more NS-records set for \'@\'';
	ELSIF emptylabels > 0 THEN
		RAISE EXCEPTION 'all labels have to have records';
	ELSE
		INSERT INTO change (nameserver_id, zone)
		SELECT nameserver.id, zone.name FROM zone, nameserver WHERE zone.id = zoneid;
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

CREATE CONSTRAINT TRIGGER zone_zonecheck_constraint AFTER INSERT OR UPDATE OR DELETE
ON zone
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE PROCEDURE verify_zone();
