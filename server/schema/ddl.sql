DROP TABLE IF EXISTS record;
DROP TABLE IF EXISTS label;
DROP TABLE IF EXISTS zone;
DROP TABLE IF EXISTS allowed_type;
DROP TABLE IF EXISTS account;
DROP TABLE IF EXISTS change;
DROP TABLE IF EXISTS slavezone_change;
DROP TABLE IF EXISTS nameserver;
DROP TABLE IF EXISTS updates_disabled;
DROP TABLE IF EXISTS allow_zonetransfer;
DROP TABLE IF EXISTS dnssec_keyset;
DROP TABLE IF EXISTS dnssec_external_key;

CREATE TYPE dnsclass AS ENUM('IN', 'CH');
CREATE TYPE changetype AS ENUM('PENDING', 'ERROR', 'OK');
CREATE TYPE dnsseckeytype AS ENUM('KSK', 'ZSK');
CREATE TYPE algorithmtype AS ENUM('RSASHA1', 'RSASHA256', 'RSASHA512', 'ECDSAP256SHA256', 'ECDSAP384SHA384');

CREATE TABLE allowed_type (
        id SERIAL PRIMARY KEY NOT NULL,
        type VARCHAR(16) UNIQUE NOT NULL,
        synopsis VARCHAR(255) NOT NULL,
        regexp TEXT NOT NULL
);

CREATE TABLE account (
        id SERIAL PRIMARY KEY NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL CHECK (email ~* '.@.'),
        hash VARCHAR(255) NOT NULL
);

CREATE TABLE updates_disabled (
	disabled INT
);

INSERT INTO updates_disabled (disabled) VALUES (0);

CREATE TABLE atomiadns_schemaversion (
	version INT
);

INSERT INTO atomiadns_schemaversion (version) VALUES (87);

CREATE TABLE allow_zonetransfer (
        id SERIAL PRIMARY KEY NOT NULL,
        zone VARCHAR(255) NOT NULL,
        ip VARCHAR(255) NOT NULL,
	UNIQUE (zone, ip)
);

CREATE TABLE dnssec_external_key (
        id SERIAL PRIMARY KEY NOT NULL,
	keydata TEXT NOT NULL
);

CREATE TABLE dnssec_keyset (
        id SERIAL PRIMARY KEY NOT NULL,
	algorithm algorithmtype NOT NULL,
	keysize INT NOT NULL CHECK (keysize >= 256),
	keytype dnsseckeytype NOT NULL,
	activated INT NOT NULL CHECK (activated IN (0, 1)),
	keydata TEXT NOT NULL,
	created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	activated_at TIMESTAMP,
	deactivated_at TIMESTAMP
);

INSERT INTO allowed_type (type, synopsis, regexp) VALUES
('A', 'ipv4address', '^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}$'),
('AAAA', 'ipv6address', E'^((([0-9A-Fa-f]{1,4}:){7}(([0-9A-Fa-f]{1,4})|:))|(([0-9A-Fa-f]{1,4}:){6}(:|((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})(\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})){3})|(:[0-9A-Fa-f]{1,4})))|(([0-9A-Fa-f]{1,4}:){5}((:((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})(\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2})))|(([0-9A-Fa-f]{1,4}:){4}(:[0-9A-Fa-f]{1,4}){0,1}((:((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})(\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2})))|(([0-9A-Fa-f]{1,4}:){3}(:[0-9A-Fa-f]{1,4}){0,2}((:((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})(\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2})))|(([0-9A-Fa-f]{1,4}:){2}(:[0-9A-Fa-f]{1,4}){0,3}((:((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})(\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2})))|(([0-9A-Fa-f]{1,4}:)(:[0-9A-Fa-f]{1,4}){0,4}((:((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})(\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2})))|(:(:[0-9A-Fa-f]{1,4}){0,5}((:((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})(\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2}))))(%.+)?$'),
('AFSDB', 'subtype hostname', '^[0-9]+ [a-z0-9][a-z0-9.-]*$'),
('CERT', 'type keytag algorithm certificate', '^[0-9]+ [0-9]+ [0-9]+ [A-Za-z0-9+/=]+$'),
('CNAME', 'hostname', '^[a-z0-9_][a-z0-9._-]*$'),
('DNAME', 'domain', '^.+$'),
('DNSKEY', 'flag protocol algorithm publickey', '^[0-9]+ [0-9]+ [0-9]+ [A-Za-z0-9+/=]+$'),
('DS', 'keytag algorithm digesttype digest', '^[0-9]+ [0-9]+ [0-9]+ [A-Za-z0-9+/=]+$'),
('HIP', 'pk-algorithm base16-encoded-hit base64-encoded-public-key [rendezvous-server ..]', '^[0-9]+ [A-F0-9]+ [A-Za-z0-9+/=]+( .*)?$'),
('IPSECKEY', 'precedence gateway-type algorithm gateway [base64-encoded-public-key]', '^[0-9]+ [0-9]+ [0-9]+ [a-z0-9][a-z0-9.-]+( [A-Za-z0-9+/=]+)?$'),
('LOC', 'd1 [m1 [s1]] N|S d2 [m2 [s2]] E|W alt [siz [hp [vp]]]', '^[0-9]{1,2}( [0-9]{1,2}?( [0-9]{1,2}([.][0-9]{1,3})?)?)? [NS] [0-9]{1,3}( [0-9]{1,2}?( [0-9]{1,2}([.][0-9]{1,3})?)?)? [EW] -?[0-9.]+m?( [0-9.]+m?){0,3}$'),
('MX', 'prio hostname', '^[0-9]+ [a-z0-9][a-z0-9.-]*$'),
('NAPTR', 'order pref flags service regexp_without_backslash replacement', '^[0-9]+ [0-9]+ "[^"]*" "[^"]*" "[^"]*" ([a-z0-9_][a-z0-9._-]+)?[.]$'),
('NS', 'hostname', '^[a-z0-9][a-z0-9.-]*$'),
('NSEC', 'hostname type [type ..]', '^[a-z0-9][a-z0-9.-]* [A-Z0-9]+( [A-Z0-9]+)*$'),
('NSEC3', 'algorithm flags iterations salt next type [.. type]', '^[0-9]+ [0-9]+ [0-9]+ (-|[A-F0-9]+) [A-Z2-7]+ [A-Z0-9]+( [A-Z0-9]+)*$'),
('NSEC3PARAM', 'algorithm flags iterations salt', '^[0-9]+ [0-9]+ [0-9]+ (-|[A-F0-9]+)$'),
('PTR', 'hostname', '^[a-z0-9][a-z0-9.-]*$'),
('RRSIG', 'type algorithm labels origttl expiration keytag signer signature', '^[A-Z0-9]+ [0-9]+ [0-9]+ [0-9]+ ([0-9]{1,10}|[0-9]{14}) [0-9]+ [a-z0-9][a-z0-9.-]+ [A-Za-z0-9+/=]+$'),
('SOA', 'mname rname %serial refresh retry expire minimum', '^[a-z0-9.-]+ [a-z0-9.-]+ %serial ([0-9]+ ){3}[0-9]+$'),
('SPF', 'spfstring', '^"v=spf[0-9][^"]*"$'),
('SRV', 'prio weight port target', '^[0-9]+ [0-9]+ [0-9]+ [a-z0-9][a-z0-9.-]+$'),
('SSHFP', 'algorithm fingerprinttype fingerprint', '^[0-9]+ [0-9]+ [0-9A-F]+$'),
('TLSA', 'usage selector type certificate', '^[0-9]+ [0-9]+ [0-9]+ [0-9A-F]+$'),
('TXT', 'quotedstring', '^"[^"]{0,255}"( "[^"]{0,255}")*$'),
('CAA', 'certificate authority authorization', '^([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5]) (issue|issuewild|iodef) ("[^"]{0,255}")*$');

CREATE TABLE nameserver_group (
        id SERIAL PRIMARY KEY NOT NULL,
        name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE nameserver (
        id SERIAL PRIMARY KEY NOT NULL,
        name VARCHAR(255) NOT NULL UNIQUE,
        nameserver_group_id INT NOT NULL REFERENCES nameserver_group
);

CREATE TABLE change (
        id BIGSERIAL PRIMARY KEY NOT NULL,
        nameserver_id INT NOT NULL REFERENCES nameserver,
        zone VARCHAR(255) NOT NULL,
	status changetype NOT NULL DEFAULT 'PENDING',
	errormessage TEXT NULL,
	changetime INT NOT NULL DEFAULT EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)
);

CREATE INDEX change_zone_index ON change(zone, nameserver_id);

CREATE TABLE slavezone_change (
        id BIGSERIAL PRIMARY KEY NOT NULL,
        nameserver_id INT NOT NULL REFERENCES nameserver,
        zone VARCHAR(255) NOT NULL,
	status changetype NOT NULL DEFAULT 'PENDING',
	errormessage TEXT NULL,
	changetime INT NOT NULL DEFAULT EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)
);

CREATE TABLE zone (
        id BIGSERIAL PRIMARY KEY NOT NULL,
        name VARCHAR(255) NOT NULL UNIQUE CONSTRAINT zone_format CHECK (name ~* '^([a-z0-9_][a-z0-9_-]*)([.][a-z0-9_][a-z0-9_-]*)*$'),
	nameserver_group_id INT NOT NULL REFERENCES nameserver_group,
	account_id INT NULL REFERENCES account
);

CREATE TABLE slavezone (
        id BIGSERIAL PRIMARY KEY NOT NULL,
        name VARCHAR(255) NOT NULL UNIQUE CONSTRAINT zone_format CHECK (name ~* '^([a-z0-9_][a-z0-9_-]*)([.][a-z0-9_][a-z0-9_-]*)*$'),
	nameserver_group_id INT NOT NULL REFERENCES nameserver_group,
	master VARCHAR(255) NOT NULL CONSTRAINT master_format CHECK (master ~* '^(([0-9]+[.]){3}[0-9]+)|(((([0-9A-Fa-f]{1,4}:){7}(([0-9A-Fa-f]{1,4})|:))|(([0-9A-Fa-f]{1,4}:){6}(:|((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})){3})|(:[0-9A-Fa-f]{1,4})))|(([0-9A-Fa-f]{1,4}:){5}((:((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2})))|(([0-9A-Fa-f]{1,4}:){4}(:[0-9A-Fa-f]{1,4}){0,1}((:((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2})))|(([0-9A-Fa-f]{1,4}:){3}(:[0-9A-Fa-f]{1,4}){0,2}((:((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2})))|(([0-9A-Fa-f]{1,4}:){2}(:[0-9A-Fa-f]{1,4}){0,3}((:((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2})))|(([0-9A-Fa-f]{1,4}:)(:[0-9A-Fa-f]{1,4}){0,4}((:((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2})))|(:(:[0-9A-Fa-f]{1,4}){0,5}((:((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2})))|(((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})){3})))(%.+)?)$'),
	tsig_name VARCHAR(255) CONSTRAINT tsig_name_format CHECK (tsig_name IS NULL OR tsig_name ~* '^[a-zA-Z0-9_-]*'),
	tsig_secret VARCHAR(255) CONSTRAINT tsig_format CHECK (tsig_secret IS NULL OR tsig_secret ~* '^[a-zA-Z0-9+/=]*'),
	account_id INT NULL REFERENCES account
);

CREATE INDEX zone_nameserver_group_idx ON zone(nameserver_group_id);

CREATE TABLE label (
        id BIGSERIAL PRIMARY KEY NOT NULL,
        zone_id BIGINT NOT NULL REFERENCES zone,
        label VARCHAR(255) NOT NULL CONSTRAINT label_format CHECK (label ~* '^(([*][.])?([a-z0-9_][a-z0-9_-]*)([.][a-z0-9_][a-z0-9_-]*)*)|[@*]$'),
	UNIQUE (zone_id, label)
);

CREATE INDEX label_zone_id ON label(zone_id);

CREATE TABLE record (
        id BIGSERIAL PRIMARY KEY NOT NULL,
        label_id BIGINT NOT NULL REFERENCES label,
        class dnsclass NOT NULL,
        type VARCHAR(16) NOT NULL,
        ttl INT NOT NULL CONSTRAINT ttl_not_negative CHECK (ttl >= 0),
        rdata TEXT NOT NULL
);

CREATE INDEX record_label_idx ON record(label_id);

CREATE TABLE zone_metadata (
        id BIGSERIAL PRIMARY KEY NOT NULL,
        zone_id BIGINT NOT NULL REFERENCES zone,
        metadata_key VARCHAR(255) NOT NULL,
        metadata_value VARCHAR(255) NOT NULL,
	UNIQUE (zone_id, metadata_key)
);

CREATE INDEX zone_metadata_zone_id_idx ON zone_metadata(zone_id);

CREATE OR REPLACE FUNCTION verify_record() RETURNS trigger AS $$
DECLARE
        mysynopsis varchar(255);
        myregexp text;
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
                RAISE EXCEPTION '% isn''t allowed rdata for %, synopsis is "%"', NEW.rdata, NEW.type, mysynopsis;
        ELSE
                RETURN NEW;
        END IF;
END; $$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER record_constraint AFTER INSERT OR UPDATE
ON record
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE PROCEDURE verify_record();

CREATE OR REPLACE FUNCTION verify_zone() RETURNS trigger AS $$
DECLARE
	numsoa int;
	numcorrectsoa int;
	numns int;
	zoneid bigint;
	labelid bigint;
	emptylabels int;
BEGIN
	IF TG_TABLE_NAME = 'zone' THEN
		IF TG_OP = 'DELETE' THEN
			INSERT INTO change (nameserver_id, zone)
			SELECT nameserver.id, OLD.name FROM nameserver WHERE nameserver.nameserver_group_id = OLD.nameserver_group_id;
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

			IF NEW.type = 'SOA' THEN
				SELECT COUNT(*) INTO numcorrectsoa FROM label l WHERE l.id = labelid AND l.label = '@';
				IF numcorrectsoa != 1 THEN
					RAISE EXCEPTION 'SOA is not allowed for anything but @';
				END IF;
			END IF;
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

	SELECT COUNT(NULLIF(type = 'SOA', false)), COUNT(NULLIF(type = 'NS', false)) INTO numsoa, numns
	FROM label l INNER JOIN record r ON l.id = r.label_id
	WHERE l.zone_id = zoneid AND l.label = '@' AND r.type IN ('SOA', 'NS');

	IF NOT FOUND THEN
		RAISE EXCEPTION 'error frinding number of soas and number of ns-records, should not happen';
	END IF;

	-- Let's relax this a bit and only check for labels not beeing empty when they are added or records are removed.
	IF (TG_TABLE_NAME = 'record' AND TG_OP = 'DELETE') OR (TG_TABLE_NAME = 'label' AND TG_OP = 'INSERT') THEN
		SELECT COUNT(*) INTO emptylabels
		FROM label l
		WHERE l.zone_id = zoneid AND NOT EXISTS (SELECT 1 FROM record WHERE label_id = l.id);
	ELSE
		emptylabels := 0;
	END IF;

	IF numsoa != 1 THEN
		RAISE EXCEPTION 'zone needs to have exactly one SOA and it should be for ''@''';
	ELSIF numns < 1 THEN
		RAISE EXCEPTION 'zone needs to have one or more NS-records set for ''@''';
	ELSIF emptylabels > 0 THEN
		RAISE EXCEPTION 'all labels have to have records';
	ELSE
		INSERT INTO change (nameserver_id, zone)
		SELECT nameserver.id, zone.name FROM zone, nameserver WHERE zone.id = zoneid AND nameserver.nameserver_group_id = zone.nameserver_group_id;
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

CREATE OR REPLACE FUNCTION slavezone_update() RETURNS trigger AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
		INSERT INTO slavezone_change (nameserver_id, zone)
		SELECT nameserver.id, OLD.name FROM nameserver WHERE nameserver.nameserver_group_id = OLD.nameserver_group_id;
		RETURN OLD;
	ELSIF TG_OP = 'UPDATE' THEN
		INSERT INTO slavezone_change (nameserver_id, zone)
		SELECT nameserver.id, OLD.name FROM nameserver WHERE nameserver.nameserver_group_id = OLD.nameserver_group_id;
	END IF;

	INSERT INTO slavezone_change (nameserver_id, zone)
	SELECT nameserver.id, NEW.name FROM nameserver WHERE nameserver.nameserver_group_id = NEW.nameserver_group_id;

	RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER slavezone_update_trigger AFTER INSERT OR UPDATE OR DELETE
ON slavezone
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE PROCEDURE slavezone_update();
