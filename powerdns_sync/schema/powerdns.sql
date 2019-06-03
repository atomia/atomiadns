-- # Our versioning table
DROP TABLE IF EXISTS powerdns_schemaversion;
CREATE TABLE powerdns_schemaversion (version INT);
INSERT INTO powerdns_schemaversion VALUES (15);

-- MySQL dump 10.13  Distrib 5.1.41, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: powerdns
-- ------------------------------------------------------
-- Server version	5.1.41-3ubuntu12.8

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Temporary table structure for view `cryptokeys`
--

DROP TABLE IF EXISTS `cryptokeys`;
/*!50001 DROP VIEW IF EXISTS `cryptokeys`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
/*!50001 CREATE TABLE `cryptokeys` (
  `id` int(11),
  `domain_id` int(11),
  `flags` int(11),
  `active` tinyint(1),
  `content` text
) ENGINE=MyISAM */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `domainmetadata`
--

DROP TABLE IF EXISTS `domainmetadata`;
/*!50001 DROP VIEW IF EXISTS `domainmetadata`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
/*!50001 CREATE TABLE `domainmetadata` (
  `domain_id` int(11),
  `kind` varchar(15),
  `content` text
) ENGINE=MyISAM */;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `outbound_tsig_keys`
--

DROP TABLE IF EXISTS `outbound_tsig_keys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `outbound_tsig_keys` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `domain_id` int(11) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `secret` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `domain_index` (`domain_id`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `domains`
--

DROP TABLE IF EXISTS `domains`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `domains` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `master` varchar(128) DEFAULT NULL,
  `last_check` int(11) DEFAULT NULL,
  `type` varchar(6) NOT NULL,
  `notified_serial` int(11) DEFAULT NULL,
  `account` varchar(40) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name_index` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `global_cryptokeys`
--

DROP TABLE IF EXISTS `global_cryptokeys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `global_cryptokeys` (
  `id` int(11) NOT NULL,
  `flags` int(11) NOT NULL,
  `active` tinyint(1) DEFAULT NULL,
  `content` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `global_domainmetadata`
--

DROP TABLE IF EXISTS `global_domainmetadata`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `global_domainmetadata` (
  `kind` varchar(32) NOT NULL,
  `content` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `records`
--

DROP TABLE IF EXISTS `records`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `records` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `domain_id` int(11) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `type` varchar(10) DEFAULT NULL,
  `content` varchar(64000) DEFAULT NULL,
  `ttl` int(11) DEFAULT NULL,
  `prio` int(11) DEFAULT NULL,
  `change_date` int(11) DEFAULT NULL,
  `disabled` TINYINT(1) DEFAULT 0,
  `auth` tinyint(1) DEFAULT 1,
  `ordername` varchar(255) BINARY DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `nametype_index` (`name`,`type`),
  KEY `domain_id` (`domain_id`),
  KEY `recordorder` (`domain_id`,`ordername`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;


--
-- Table structure for table `supermasters`
--

DROP TABLE IF EXISTS `supermasters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `supermasters` (
  `ip` varchar(64) NOT NULL,
  `nameserver` varchar(255) NOT NULL,
  `account` varchar(40) NOT NULL,
  PRIMARY KEY (ip, nameserver)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Final view structure for view `cryptokeys`
--

/*!50001 DROP TABLE IF EXISTS `cryptokeys`*/;
/*!50001 DROP VIEW IF EXISTS `cryptokeys`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = latin1 */;
/*!50001 SET character_set_results     = latin1 */;
/*!50001 SET collation_connection      = latin1_swedish_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `cryptokeys` AS 
SELECT
  `c`.`id` AS `id`,
  `d`.`id` AS `domain_id`,
  `c`.`flags` AS `flags`,
  `c`.`active` AS `active`,
  `c`.`content` AS `content`
FROM (
  `powerdns`.`domains` `d`
  JOIN `powerdns`.`global_cryptokeys` `c`
)
WHERE `d`.`type` IN ('NATIVE', 'MASTER')
*/;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `domainmetadata`
--

/*!50001 DROP TABLE IF EXISTS `domainmetadata`*/;
/*!50001 DROP VIEW IF EXISTS `domainmetadata`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = latin1 */;
/*!50001 SET character_set_results     = latin1 */;
/*!50001 SET collation_connection      = latin1_swedish_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `domainmetadata` AS 
SELECT
  d.id AS domain_id,
  IF(d.type IN ('NATIVE', 'MASTER'), IF(g.kind IS NULL, gp.kind, g.kind), 'AXFR-MASTER-TSIG') AS kind,
  IF(d.type IN ('NATIVE', 'MASTER'),
    IF(g.kind IS NULL, gp.content, g.content),
    concat('key', k.id, ':', lcase(k.name))) AS content
FROM domains d
LEFT JOIN global_domainmetadata g ON d.type IN ('NATIVE', 'MASTER') AND
  (SELECT count(0) FROM global_cryptokeys) > 0
LEFT JOIN global_domainmetadata gp ON g.kind IS NULL AND d.type = 'MASTER' AND
  (SELECT count(0) FROM global_cryptokeys) = 0
LEFT JOIN outbound_tsig_keys k ON k.domain_id = d.id AND d.type = 'SLAVE'
WHERE d.type IN ('NATIVE', 'MASTER', 'SLAVE')
*/;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `tsigkeys` AS select CONCAT('key', k.id, ':', LOWER(k.name)) AS name, 'hmac-md5' AS algorithm, k.secret from outbound_tsig_keys k */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

CREATE TABLE comments (
  id                    INT AUTO_INCREMENT,
  domain_id             INT NOT NULL,
  name                  VARCHAR(255) NOT NULL,
  type                  VARCHAR(10) NOT NULL,
  modified_at           INT NOT NULL,
  account               VARCHAR(40) NOT NULL,
  comment               VARCHAR(64000) NOT NULL,
  PRIMARY KEY(id)
) Engine=InnoDB;

CREATE INDEX comments_domain_id_idx ON comments (domain_id);
CREATE INDEX comments_name_type_idx ON comments (name, type);
CREATE INDEX comments_order_idx ON comments (domain_id, modified_at);

-- Dump completed on 2011-04-15 10:55:35

DROP VIEW IF EXISTS domainmetadata;
CREATE TABLE domainmetadata (
  id                    INT AUTO_INCREMENT,
  domain_id             INT NOT NULL,
  kind                  VARCHAR(32),
  content               TEXT,
  PRIMARY KEY(id)
) Engine=InnoDB CHARACTER SET 'latin1';

CREATE INDEX domainmetadata_idx ON domainmetadata (domain_id, kind);

INSERT INTO domainmetadata(domain_id, kind, content)
SELECT
  d.id AS domain_id,
  IF(d.type IN ('NATIVE', 'MASTER'), IF(g.kind IS NULL, gp.kind, g.kind), 'AXFR-MASTER-TSIG') AS kind,
  IF(d.type IN ('NATIVE', 'MASTER'),
    IF(g.kind IS NULL, gp.content, g.content),
    concat('key', k.id, ':', lcase(k.name))) AS content
FROM domains d
LEFT JOIN global_domainmetadata g ON d.type IN ('NATIVE', 'MASTER') AND
  (SELECT count(0) FROM global_cryptokeys) > 0
LEFT JOIN global_domainmetadata gp ON g.kind IS NULL AND d.type = 'MASTER' AND
  (SELECT count(0) FROM global_cryptokeys) = 0
LEFT JOIN outbound_tsig_keys k ON k.domain_id = d.id AND d.type = 'SLAVE'
WHERE d.type IN ('NATIVE', 'MASTER', 'SLAVE');

DELIMITER //
DROP PROCEDURE IF EXISTS sync_global_domainmetadata //
CREATE PROCEDURE sync_global_domainmetadata
(
    IN trigger_operation varchar(10),
    IN old_kind VARCHAR(32),
    IN old_content TEXT,
    IN new_kind VARCHAR(32),
    IN new_content TEXT
)
BEGIN
    DECLARE global_cryptokeys_count INT DEFAULT 0;

    IF trigger_operation = 'INSERT' THEN

        SET global_cryptokeys_count = (SELECT count(0) FROM global_cryptokeys);

        IF global_cryptokeys_count > 0 THEN
            INSERT INTO domainmetadata (domain_id, kind, content)
            SELECT 
            d.id AS domain_id,
            IF(d.type IN ('NATIVE', 'MASTER'), new_kind, 'AXFR-MASTER-TSIG') AS kind,
            IF(d.type IN ('NATIVE', 'MASTER'),
                new_content,
                concat('key', k.id, ':', lcase(k.name))) AS content
            FROM domains d
            LEFT JOIN outbound_tsig_keys k ON k.domain_id = d.id AND d.type = 'SLAVE'
            WHERE d.type IN ('NATIVE', 'MASTER', 'SLAVE');
        ELSE
            INSERT INTO domainmetadata (domain_id, kind, content)
            SELECT 
            d.id AS domain_id,
            IF(d.type IN ('MASTER'), new_kind, 'AXFR-MASTER-TSIG') AS kind,
            IF(d.type IN ('MASTER'),
                new_content,
                concat('key', k.id, ':', lcase(k.name))) AS content
            FROM domains d
            LEFT JOIN outbound_tsig_keys k ON k.domain_id = d.id AND d.type = 'SLAVE'
            WHERE d.type IN ('MASTER', 'SLAVE');
        END IF;
    ELSEIF trigger_operation = 'UPDATE' THEN
        UPDATE domainmetadata
        SET kind = new_kind,
            content = new_content
        WHERE kind = old_kind
            AND content = old_content;
    ELSEIF trigger_operation = 'DELETE' THEN
        DELETE dm FROM domainmetadata AS dm WHERE dm.kind = old_kind AND dm.content = old_content;
    END IF;
END //

DROP PROCEDURE IF EXISTS sync_domains_domainmetadata //
CREATE PROCEDURE sync_domains_domainmetadata
(
    IN trigger_operation varchar(10),
    IN domain_id BIGINT,
    in domain_type varchar(6)
)
BEGIN
    DECLARE global_domainmetadata_count INT DEFAULT 0;
    SET global_domainmetadata_count = (SELECT count(0) FROM global_domainmetadata);

    IF global_domainmetadata_count > 0 THEN
        IF trigger_operation = 'INSERT' THEN
            IF domain_type = 'NATIVE' OR domain_type = 'MASTER' THEN
                INSERT INTO domainmetadata(domain_id, kind, content)
                SELECT
                domain_id,
                g.kind AS kind,
                g.content
                FROM global_domainmetadata AS g;
            ELSEIF domain_type = 'SLAVE' THEN
                INSERT INTO domainmetadata(domain_id, kind, content)
                SELECT
                domain_id,
                g.kind AS kind,
                concat('key', k.id, ':', lcase(k.name)) AS content
                FROM global_domainmetadata AS g
                LEFT JOIN outbound_tsig_keys k ON k.domain_id = domain_id;
            END IF;
        ELSEIF trigger_operation = 'DELETE' THEN
            DELETE gd FROM domainmetadata AS gd WHERE gd.domain_id = domain_id;
        END IF;
    END IF;
END //

DROP PROCEDURE IF EXISTS sync_cryptokeys_domainmetadata //
CREATE PROCEDURE sync_cryptokeys_domainmetadata
(
    IN trigger_operation varchar(10)
)
BEGIN
    DECLARE global_domainmetadata_count INT DEFAULT 0;
    SET global_domainmetadata_count = (SELECT count(0) FROM global_domainmetadata);

    IF global_domainmetadata_count > 0 THEN
        DELETE FROM domainmetadata;
        IF trigger_operation = 'INSERT' THEN
            INSERT INTO domainmetadata(domain_id, kind, content)
            SELECT d.id AS domain_id,
            IF(d.TYPE IN ( 'NATIVE', 'MASTER' ), g.kind, 'AXFR-MASTER-TSIG') AS kind,
            IF(d.TYPE IN ( 'NATIVE', 'MASTER' ), g.content,  Concat('key', k.id, ':', Lcase(k.name))) AS content
            FROM   domains d
                    left join global_domainmetadata g
                            ON d.TYPE IN ( 'NATIVE', 'MASTER' )
                    left join outbound_tsig_keys k
                            ON k.domain_id = d.id
                            AND d.TYPE = 'SLAVE'
            WHERE d.type IN ('NATIVE', 'MASTER', 'SLAVE');
        ELSEIF trigger_operation = 'DELETE' THEN
            INSERT INTO domainmetadata(domain_id, kind, content)
            SELECT
            d.id AS domain_id,
            IF(d.type = 'MASTER', gp.kind, 'AXFR-MASTER-TSIG') AS kind,
            IF(d.type = 'MASTER', gp.content, concat('key', k.id, ':', lcase(k.name))) AS content
            FROM domains d
            LEFT JOIN global_domainmetadata gp ON d.type = 'MASTER'
            LEFT JOIN outbound_tsig_keys k ON k.domain_id = d.id AND d.type = 'SLAVE'
            WHERE d.type IN ('MASTER', 'SLAVE');
        END IF;
    END IF;
END //

DROP TRIGGER IF EXISTS insert_domainmetadata //
CREATE TRIGGER insert_domainmetadata AFTER INSERT ON global_domainmetadata
FOR EACH ROW
BEGIN
  call sync_global_domainmetadata('INSERT', '', '', NEW.kind, NEW.content);
END//

DROP TRIGGER IF EXISTS update_domainmetadata //
CREATE TRIGGER update_domainmetadata AFTER UPDATE ON global_domainmetadata
FOR EACH ROW
BEGIN
  call sync_global_domainmetadata('UPDATE', OLD.kind, OLD.content, NEW.kind, NEW.content);
END//

DROP TRIGGER IF EXISTS delete_domainmetadata //
CREATE TRIGGER delete_domainmetadata AFTER DELETE ON global_domainmetadata
FOR EACH ROW
BEGIN
  call sync_global_domainmetadata('DELETE', OLD.kind, OLD.content, '', '');
END//

DROP TRIGGER IF EXISTS insert_domain //
CREATE TRIGGER insert_domain AFTER INSERT ON domains
FOR EACH ROW
BEGIN
  call sync_domains_domainmetadata('INSERT', NEW.id, NEW.type);
END//

DROP TRIGGER IF EXISTS delete_domain //
CREATE TRIGGER delete_domain AFTER DELETE ON domains
FOR EACH ROW
BEGIN
  call sync_domains_domainmetadata('DELETE', OLD.id, '');
END//

DROP TRIGGER IF EXISTS insert_cryptokey //
CREATE TRIGGER insert_cryptokey AFTER INSERT ON global_cryptokeys
FOR EACH ROW
BEGIN
    DECLARE cryptokeys_count INT;
    SET cryptokeys_count = (SELECT count(0) FROM global_cryptokeys);
    IF cryptokeys_count = 1 THEN
        call sync_cryptokeys_domainmetadata('INSERT');
    END IF;
END//

DROP TRIGGER IF EXISTS delete_cryptokey //
CREATE TRIGGER delete_cryptokey AFTER DELETE ON global_cryptokeys
FOR EACH ROW
BEGIN
    DECLARE cryptokeys_count INT;
    SET cryptokeys_count = (SELECT count(0) FROM global_cryptokeys);
    IF cryptokeys_count = 0 THEN
        call sync_cryptokeys_domainmetadata('DELETE');
    END IF;
END//
DELIMITER ;

ALTER TABLE domains MODIFY account VARCHAR(40) CHARACTER SET 'utf8' DEFAULT NULL;

CREATE INDEX ordername ON records (ordername);
DROP INDEX recordorder ON records;

ALTER TABLE supermasters MODIFY account VARCHAR(40) CHARACTER SET 'utf8' NOT NULL;

ALTER TABLE comments MODIFY account VARCHAR(40) CHARACTER SET 'utf8' DEFAULT NULL;
ALTER TABLE comments MODIFY comment TEXT CHARACTER SET 'utf8' NOT NULL;
ALTER TABLE comments CHARACTER SET 'latin1';
DROP INDEX comments_domain_id_idx ON comments;
