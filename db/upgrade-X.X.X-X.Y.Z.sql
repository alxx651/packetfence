--                                                                                                                     
-- PacketFence SQL schema upgrade from 9.1.0 to 9.1.9
--                                                                                                                     
                                                                                                                       

--
-- Setting the major/minor/sub-minor version of the DB                                                                 
--                                                                                                                     

SET @MAJOR_VERSION = 9;
SET @MINOR_VERSION = 1;
SET @SUBMINOR_VERSION = 9;



SET @PREV_MAJOR_VERSION = 9;
SET @PREV_MINOR_VERSION = 1;
SET @PREV_SUBMINOR_VERSION = 0;
                                                                                                                       

--                                                                                                                     
-- The VERSION_INT to ensure proper ordering of the version in queries
--                                                                                                                     

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @SUBMINOR_VERSION;                                     

SET @PREV_VERSION_INT = @PREV_MAJOR_VERSION << 16 | @PREV_MINOR_VERSION << 8 | @PREV_SUBMINOR_VERSION;                 

DROP PROCEDURE IF EXISTS ValidateVersion;                                                                              
--
-- Updating to current version
--  
DELIMITER //
CREATE PROCEDURE ValidateVersion()
BEGIN                                                                                                                  
    DECLARE PREVIOUS_VERSION int(11);
    DECLARE PREVIOUS_VERSION_STRING varchar(11);
    DECLARE _message varchar(255);
    SELECT id, version INTO PREVIOUS_VERSION, PREVIOUS_VERSION_STRING FROM pf_version ORDER BY id DESC LIMIT 1;        
              
      IF PREVIOUS_VERSION != @PREV_VERSION_INT THEN                                                                    
        SELECT CONCAT('PREVIOUS VERSION ', PREVIOUS_VERSION_STRING, ' DOES NOT MATCH ', CONCAT_WS('.', @PREV_MAJOR_VERSION, @PREV_MINOR_VERSION, @PREV_SUBMINOR_VERSION)) INTO _message;
        SIGNAL SQLSTATE VALUE '99999'                                                                                  
              SET MESSAGE_TEXT = _message;                                                                             
      END IF;                                                                                                          
END
//                                                                                                                     

DELIMITER ;                                                                                                            
call ValidateVersion;                                                                                                  
DROP PROCEDURE IF EXISTS ValidateVersion;

--
-- Table structure for table `admin_api_audit_log`
--

CREATE TABLE `admin_api_audit_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `tenant_id` int(11) NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `user_name` varchar(255) DEFAULT NULL,
  `action` varchar(255) DEFAULT NULL,
  `object_id` varchar(255) DEFAULT NULL,
  `url` varchar(255) DEFAULT NULL,
  `method` varchar(10) DEFAULT NULL,
  `request` TEXT,
  `status` int NOT NULL,
   PRIMARY KEY (`id`),
   KEY `action` (`action`),
   KEY `user_name` (`user_name`),
   KEY `object_id_action` (`object_id`, `action`),
   KEY `created_at` (`created_at`)
) ENGINE=InnoDB;

--
-- Add an index on ssid on the locationlog
--

ALTER TABLE locationlog ADD INDEX `locationlog_ssid` (`ssid`);

--
-- Table structure for table `locationlog_history`
--

CREATE TABLE `locationlog_history` (
  `id` int NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `tenant_id` int NOT NULL DEFAULT 1,
  `mac` varchar(17) default NULL,
  `switch` varchar(17) NOT NULL default '',
  `port` varchar(20) NOT NULL default '',
  `vlan` varchar(50) default NULL,
  `role` varchar(255) default NULL,
  `connection_type` varchar(50) NOT NULL default '',
  `connection_sub_type` varchar(50) default NULL,
  `dot1x_username` varchar(255) NOT NULL default '',
  `ssid` varchar(32) NOT NULL default '',
  `start_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `end_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `switch_ip` varchar(17) DEFAULT NULL,
  `switch_mac` varchar(17) DEFAULT NULL,
  `stripped_user_name` varchar (255) DEFAULT NULL,
  `realm`  varchar (255) DEFAULT NULL,
  `session_id` VARCHAR(255) DEFAULT NULL,
  `ifDesc` VARCHAR(255) DEFAULT NULL,
  `voip` enum('no','yes') NOT NULL DEFAULT 'no',
  KEY `locationlog_view_mac` (`mac`, `end_time`),
  KEY `locationlog_end_time` ( `end_time`),
  KEY `locationlog_view_switchport` (`switch`,`port`,`end_time`,`vlan`)
) ENGINE=InnoDB;

INSERT INTO locationlog_history (
 `tenant_id`, `mac`, `switch`, `port`, `vlan`, `role`, `connection_type`, 
 `connection_sub_type`, `dot1x_username`, `ssid`, `start_time`, `end_time`, `switch_ip`, 
 `switch_mac`, `stripped_user_name`, `realm`, `session_id`, `ifDesc`, `voip`)  
    SELECT `tenant_id`, `mac`, `switch`, `port`, `vlan`, `role`, `connection_type`, 
    `connection_sub_type`, `dot1x_username`, `ssid`, `start_time`, `end_time`, `switch_ip`,
    `switch_mac`, `stripped_user_name`, `realm`, `session_id`, `ifDesc`, `voip` 
    FROM locationlog WHERE end_time != '0000-00-00 00:00:00';

DELETE FROM locationlog WHERE end_time != '0000-00-00 00:00:00';

DELETE FROM locationlog 
    WHERE
    id IN (
        SELECT * FROM (
            SELECT
                `locationlog2`.id 
            FROM
                locationlog as locationlog1 
            LEFT OUTER JOIN
                `locationlog` AS `locationlog2`         
                    ON (
                        (
                            (
                                `locationlog1`.`start_time` < `locationlog2`.`start_time`                     
                                OR `locationlog1`.`start_time` IS NULL                     
                                OR (
                                    `locationlog1`.`start_time` = `locationlog2`.`start_time`                         
                                    AND `locationlog1`.`id` < `locationlog2`.`id`                     
                                )                 
                            )                 
                            AND `locationlog1`.`mac` = `locationlog2`.`mac`                 
                            AND `locationlog1`.`tenant_id` = `locationlog2`.`tenant_id`             
                        )         
                    ) 
            WHERE
                (
                    (
                        `locationlog2`.`id` IS NOT NULL         
                    )     
                ) 
        ) as x
    );

ALTER TABLE `locationlog`
    DROP PRIMARY KEY,
    DROP COLUMN id,
    ADD  PRIMARY KEY (`tenant_id`, `mac`),
    ADD CONSTRAINT `locationlog_tenant_id` FOREIGN KEY(`tenant_id`) REFERENCES `tenant` (`id`);

INSERT INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION)); 
