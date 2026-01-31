-- SQL Setup for MariaDB
-- Run this in your database to set up automatic triggers and events
-- 
-- Requirements:
-- - MariaDB 10.2+ or MySQL 5.7+
-- - Event scheduler enabled: SET GLOBAL event_scheduler = ON;

-- Create database (if not exists)
CREATE DATABASE IF NOT EXISTS fivem_dialogs 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE fivem_dialogs;

-- Main table for dialog data
CREATE TABLE IF NOT EXISTS advance_dialog_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    identifier VARCHAR(100) NOT NULL,
    resource VARCHAR(100) NOT NULL,
    dialog_id VARCHAR(100),
    data_key VARCHAR(255) NOT NULL,
    data_value TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_data (identifier, resource, data_key),
    INDEX idx_identifier (identifier),
    INDEX idx_updated (updated_at),
    INDEX idx_resource (resource)
) ENGINE=InnoDB;

-- Trigger: Automatically delete oldest entry when player reaches 100 entries
-- This ensures no player can exceed the limit, and oldest data is removed first
DELIMITER //
CREATE TRIGGER IF NOT EXISTS trg_advance_dialog_limit_100
BEFORE INSERT ON advance_dialog_data
FOR EACH ROW
BEGIN
    DECLARE entry_count INT;
    
    -- Count current entries for this player
    SELECT COUNT(*) INTO entry_count 
    FROM advance_dialog_data 
    WHERE identifier = NEW.identifier 
    AND resource = NEW.resource;
    
    -- If at or over limit, delete the oldest entry
    IF entry_count >= 100 THEN
        DELETE FROM advance_dialog_data 
        WHERE identifier = NEW.identifier 
        AND resource = NEW.resource
        ORDER BY created_at ASC 
        LIMIT 1;
    END IF;
END//
DELIMITER ;

-- Event: Automatically cleanup entries older than 30 days every 24 hours
-- This runs automatically without any Lua code
DELIMITER //
CREATE EVENT IF NOT EXISTS evt_advance_dialog_cleanup
ON SCHEDULE EVERY 24 HOUR
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    DELETE FROM advance_dialog_data 
    WHERE updated_at < DATE_SUB(NOW(), INTERVAL 30 DAY);
END//
DELIMITER ;

-- Enable event scheduler (run this once manually)
-- SET GLOBAL event_scheduler = ON;

-- Verify setup
-- SHOW VARIABLES LIKE 'event_scheduler';
-- SHOW TRIGGERS LIKE 'trg_advance_dialog%';
-- SHOW EVENTS LIKE 'evt_advance_dialog%';
