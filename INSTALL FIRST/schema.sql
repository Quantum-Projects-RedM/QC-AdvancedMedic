-- =========================================================
-- QC-ADVANCED MEDIC - OPTIMIZED DATABASE SCHEMA (4 Tables)
-- =========================================================
-- Simplified from 8 tables to 4 core tables for better performance
-- Maintains all functionality while reducing complexity
-- Tables: player_wounds, medical_treatments, player_infections, medical_history
-- =========================================================

-- =========================================================
-- TABLE 1: PLAYER WOUNDS (Core wound data)
-- =========================================================
CREATE TABLE IF NOT EXISTS `player_wounds` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `body_part` varchar(20) NOT NULL,
    `pain_level` int(2) NOT NULL DEFAULT 0,
    `bleeding_level` int(2) NOT NULL DEFAULT 0,
    `weapon_data` varchar(50) DEFAULT NULL,
    `weapon_hash` bigint(20) DEFAULT NULL,
    `weapon_name` varchar(100) DEFAULT NULL,
    `damage_type` varchar(100) DEFAULT NULL,
    `wound_description` text DEFAULT NULL,
    `is_scar` tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Whether wound has healed into a scar',
    `scar_time` timestamp NULL DEFAULT NULL COMMENT 'When wound became a scar',
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_wound` (`citizenid`, `body_part`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_is_scar` (`is_scar`),
    KEY `idx_scar_time` (`scar_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================
-- TABLE 2: MEDICAL TREATMENTS (All treatments consolidated)
-- =========================================================
CREATE TABLE IF NOT EXISTS `medical_treatments` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `body_part` varchar(20) NOT NULL,
    `treatment_type` enum('bandage', 'tourniquet', 'medicine', 'injection') NOT NULL,
    `item_type` varchar(50) NOT NULL COMMENT 'cotton_bandage, silk_bandage, morphine, etc.',
    `applied_by` varchar(50) NOT NULL COMMENT 'citizenid of who applied it (self vs medic)',
    `applied_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expiration_time` timestamp NULL DEFAULT NULL COMMENT 'When bandage expires (time-based)',
    `duration` int(11) DEFAULT NULL COMMENT 'Duration for medicines/tourniquets in seconds',
    `is_active` tinyint(1) NOT NULL DEFAULT 1 COMMENT 'Whether treatment is still active/expired',
    `original_pain_level` int(2) DEFAULT NULL COMMENT 'Original pain before treatment',
    `original_bleeding_level` int(2) DEFAULT NULL COMMENT 'Original bleeding before treatment',
    `pain_reduction` int(2) DEFAULT NULL COMMENT 'How much pain was reduced',
    `bleeding_reduction` int(2) DEFAULT NULL COMMENT 'How much bleeding was reduced',
    `metadata` json DEFAULT NULL COMMENT 'Treatment-specific data, side effects, etc.',
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_body_part` (`body_part`),
    KEY `idx_active` (`is_active`),
    KEY `idx_applied_time` (`applied_time`),
    KEY `idx_treatment_type` (`treatment_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================
-- TABLE 3: PLAYER INFECTIONS (Infections with immunity)
-- =========================================================
CREATE TABLE IF NOT EXISTS `player_infections` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `body_part` varchar(20) NOT NULL,
    `infection_percentage` int(3) NOT NULL DEFAULT 0 COMMENT 'Infection buildup 0-100%',
    `stage` int(2) NOT NULL DEFAULT 0 COMMENT 'Current infection stage (0=none, 1-4=stages)',
    `wound_type` varchar(50) DEFAULT NULL COMMENT 'bullet_stuck, bullet_fragmented, etc.',
    `start_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_progress_check` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `cure_progress` int(3) NOT NULL DEFAULT 0 COMMENT 'Cure progress 0-100%',
    `immunity_end_time` timestamp NULL DEFAULT NULL COMMENT 'When immunity from treatment expires',
    `metadata` json DEFAULT NULL COMMENT 'symptoms, treatments, progression data',
    `is_active` tinyint(1) NOT NULL DEFAULT 1,
    `cured_at` timestamp NULL DEFAULT NULL,
    `cured_by` varchar(50) DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_infection` (`citizenid`, `body_part`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_active` (`is_active`),
    KEY `idx_infection_percentage` (`infection_percentage`),
    KEY `idx_stage` (`stage`),
    KEY `idx_start_time` (`start_time`),
    KEY `idx_immunity` (`immunity_end_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================
-- OPTIONAL: MEDICAL HISTORY (Audit trail - can be added later)
-- =========================================================
CREATE TABLE IF NOT EXISTS `medical_history` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `event_type` enum('wound_created', 'wound_change', 'treatment_applied', 'treatment_change', 'treatment_removed', 'infection_started', 'infection_cured', 'wound_healed', 'wound_scarred', 'admin_clear_wounds', 'medical_inspection') NOT NULL,
    `body_part` varchar(20) DEFAULT NULL,
    `details` json NOT NULL,
    `performed_by` varchar(50) DEFAULT NULL,
    `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_event_type` (`event_type`),
    KEY `idx_timestamp` (`timestamp`),
    KEY `idx_performed_by` (`performed_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================
-- STORED PROCEDURES FOR OPTIMIZED OPERATIONS
-- =========================================================

-- Get complete medical profile (optimized single call)
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS `GetCompleteMedicalProfile`(IN `player_citizenid` VARCHAR(50))
BEGIN
    -- Get active wounds
    SELECT 'wounds' as data_type, w.* 
    FROM `player_wounds` w 
    WHERE w.`citizenid` = player_citizenid;
    
    -- Get active treatments (consolidated)
    SELECT 'treatments' as data_type, t.* 
    FROM `medical_treatments` t 
    WHERE t.`citizenid` = player_citizenid AND t.`is_active` = 1
    ORDER BY t.`applied_time` DESC;
    
    -- Get active infections (with immunity)
    SELECT 'infections' as data_type, i.* 
    FROM `player_infections` i 
    WHERE i.`citizenid` = player_citizenid AND i.`is_active` = 1;
END$$
DELIMITER ;

-- Clean up expired treatments and immunity
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS `CleanupExpiredMedicalData`()
BEGIN
    -- Deactivate expired medicine effects
    UPDATE `medical_treatments` 
    SET `is_active` = 0, `removed_at` = NOW()
    WHERE `treatment_type` IN ('medicine', 'injection') 
    AND `duration` IS NOT NULL 
    AND TIMESTAMPADD(SECOND, `duration`, `applied_time`) < NOW() 
    AND `is_active` = 1;
    
    -- Clear expired infection immunity
    UPDATE `player_infections` 
    SET `immunity_end_time` = NULL, `immunity_granted_by` = NULL
    WHERE `immunity_end_time` < NOW() AND `immunity_end_time` IS NOT NULL;
    
    -- Clean up old inactive treatments (older than 24 hours)
    DELETE FROM `medical_treatments` 
    WHERE `is_active` = 0 AND `removed_at` < DATE_SUB(NOW(), INTERVAL 24 HOUR);
    
    -- Archive old medical history (older than 30 days)
    DELETE FROM `medical_history` 
    WHERE `timestamp` < DATE_SUB(NOW(), INTERVAL 30 DAY);
END$$
DELIMITER ;

-- =========================================================
-- EXAMPLE DATA FOR TESTING
-- =========================================================

-- Example: Cotton bandage applied by self
-- INSERT INTO medical_treatments 
-- (citizenid, body_part, treatment_type, item_type, applied_by, effectiveness, decay_rate, metadata)
-- VALUES 
-- ('ABC123', 'RLEG', 'bandage', 'cotton_bandage', 'ABC123', 75.0, 2.5, 
--  '{"bandage_quality": "basic", "dirty_factor": 0.0, "self_applied": true}');

-- Example: Silk bandage applied by medic
-- INSERT INTO medical_treatments 
-- (citizenid, body_part, treatment_type, item_type, applied_by, effectiveness, decay_rate, metadata)
-- VALUES 
-- ('ABC123', 'RLEG', 'bandage', 'silk_bandage', 'DEF456', 95.0, 1.0,
--  '{"bandage_quality": "premium", "medic_skill": "expert", "sterile": true}');

-- =========================================================
-- VIEWS FOR EASY NUI ACCESS
-- =========================================================

-- View for active medical status (NUI friendly)
CREATE OR REPLACE VIEW `active_medical_status` AS
SELECT 
    w.citizenid,
    w.body_part,
    'wound' as condition_type,
    CONCAT(w.damage_type, ' (Pain: ', w.pain_level, ', Bleeding: ', w.bleeding_level, ')') as description,
    w.created_at as condition_start,
    -- Get latest treatment info
    (SELECT CONCAT(t.item_type, ' by ', 
                   CASE 
                       WHEN t.applied_by = w.citizenid THEN 'self' 
                       ELSE 'medic' 
                   END,
                   ' (', ROUND(t.effectiveness, 1), '% effective)')
     FROM medical_treatments t 
     WHERE t.citizenid = w.citizenid 
     AND t.body_part = w.body_part 
     AND t.is_active = 1 
     ORDER BY t.applied_time DESC 
     LIMIT 1) as latest_treatment
FROM player_wounds w
UNION ALL
SELECT 
    i.citizenid,
    i.body_part,
    'infection' as condition_type,
    CONCAT(i.infection_type, ' - Stage ', i.stage) as description,
    i.start_time as condition_start,
    CASE 
        WHEN i.immunity_end_time > NOW() THEN CONCAT('Immune until ', i.immunity_end_time)
        ELSE NULL 
    END as latest_treatment
FROM player_infections i
WHERE i.is_active = 1;