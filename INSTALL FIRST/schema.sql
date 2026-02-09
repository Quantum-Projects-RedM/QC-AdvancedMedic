-- =========================================================
-- QC-ADVANCED MEDIC - DATABASE SCHEMA v0.4.0 (Simplified)
-- =========================================================
-- Global bleeding + bandage cycle system
-- Tables: player_wounds (global), medical_treatments, player_infection, player_fractures, medical_history
--
-- IMPORTANT: If upgrading from v0.3.x, DROP the old player_wounds table first:
--   DROP TABLE IF EXISTS player_wounds;
-- Then run this entire schema.
-- =========================================================

-- =========================================================
-- TABLE 1: PLAYER WOUNDS (Global medical state - one row per player)
-- =========================================================
-- Replaced per-body-part wounds with single global bleeding + bandage cycle state
CREATE TABLE IF NOT EXISTS `player_wounds` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `bleeding_level` decimal(4,1) NOT NULL DEFAULT 0.0 COMMENT 'Global bleeding level 0-10',
    `bandage_changes_needed` int(3) NOT NULL DEFAULT 0 COMMENT 'Total bandage changes required to heal',
    `bandage_changes_applied` int(3) NOT NULL DEFAULT 0 COMMENT 'Bandage changes completed so far',
    `last_wound_source` varchar(100) DEFAULT NULL COMMENT 'Last weapon/damage source description',
    `metadata` json DEFAULT NULL COMMENT 'Additional wound metadata (timestamps, etc)',
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_player` (`citizenid`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_bleeding_level` (`bleeding_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================
-- TABLE 2: MEDICAL TREATMENTS (Active bandage tracking)
-- =========================================================
CREATE TABLE IF NOT EXISTS `medical_treatments` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `treatment_type` enum('bandage', 'tourniquet', 'medicine', 'injection') NOT NULL,
    `item_type` varchar(50) NOT NULL COMMENT 'cloth, cotton, linen, sterile, etc.',
    `applied_by` varchar(50) NOT NULL COMMENT 'citizenid of who applied it (self vs medic)',
    `applied_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expiration_time` timestamp NULL DEFAULT NULL COMMENT 'When bandage expires',
    `is_active` tinyint(1) NOT NULL DEFAULT 1 COMMENT 'Whether treatment is still active',
    `bleeding_reduction` int(2) DEFAULT NULL COMMENT 'How much bleeding was reduced',
    `metadata` json DEFAULT NULL COMMENT 'Treatment-specific data',
    `removed_at` timestamp NULL DEFAULT NULL COMMENT 'When treatment was deactivated',
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_active` (`is_active`),
    KEY `idx_applied_time` (`applied_time`),
    KEY `idx_treatment_type` (`treatment_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================
-- TABLE 3: PLAYER INFECTION (Global infection tracking)
-- =========================================================
-- Single global infection level per player (0-100)
-- Stage calculated from level: 0=none, 1-20=mild, 21-50=moderate, 51-80=severe, 81-100=critical
CREATE TABLE IF NOT EXISTS `player_infection` (
    `citizenid` varchar(50) NOT NULL,
    `infection_level` int(3) NOT NULL DEFAULT 0 COMMENT 'Global infection level 0-100',
    `infection_stage` int(1) NOT NULL DEFAULT 0 COMMENT 'Infection stage 0-4',
    `infection_sources` json DEFAULT NULL COMMENT 'Sources that caused infection',
    `timestamp` bigint(20) NOT NULL DEFAULT 0 COMMENT 'When infection started',
    `last_progress_check` bigint(20) NOT NULL DEFAULT 0 COMMENT 'Last progression check time',
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`),
    KEY `idx_infection_level` (`infection_level`),
    KEY `idx_infection_stage` (`infection_stage`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================
-- TABLE 4: PLAYER FRACTURES (Separate from wounds)
-- =========================================================
CREATE TABLE IF NOT EXISTS `player_fractures` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `body_part` varchar(20) NOT NULL,
    `fracture_type` enum('fracture', 'bone_break') NOT NULL,
    `severity` int(2) NOT NULL DEFAULT 5 COMMENT 'Severity 1-10',
    `pain_level` decimal(3,1) NOT NULL DEFAULT 0.0,
    `mobility_impact` decimal(3,2) NOT NULL DEFAULT 0.0 COMMENT 'Movement impairment 0.0-1.0',
    `healing_progress` decimal(5,2) NOT NULL DEFAULT 0.0 COMMENT 'Healing progress 0-100%',
    `requires_surgery` tinyint(1) DEFAULT FALSE,
    `fracture_description` text COMMENT 'Detailed description',
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `healed_at` timestamp NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_fracture` (`citizenid`, `body_part`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_healing_progress` (`healing_progress`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================
-- TABLE 5: MEDICAL HISTORY (Audit trail)
-- =========================================================
CREATE TABLE IF NOT EXISTS `medical_history` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `event_type` varchar(50) NOT NULL COMMENT 'wound_created, bandage_applied, infection_update, etc.',
    `body_part` varchar(20) DEFAULT NULL,
    `details` json NOT NULL,
    `performed_by` varchar(50) DEFAULT NULL,
    `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_event_type` (`event_type`),
    KEY `idx_timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================
-- STORED PROCEDURES
-- =========================================================

-- Clean up expired treatments
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS `CleanupExpiredMedicalData`()
BEGIN
    -- Deactivate expired medicine effects
    UPDATE `medical_treatments`
    SET `is_active` = 0, `removed_at` = NOW()
    WHERE `expiration_time` IS NOT NULL
    AND `expiration_time` < NOW()
    AND `is_active` = 1;

    -- Clean up old inactive treatments (older than 24 hours)
    DELETE FROM `medical_treatments`
    WHERE `is_active` = 0 AND `removed_at` < DATE_SUB(NOW(), INTERVAL 24 HOUR);

    -- Clean up healed wounds (no bleeding, all bandage changes done)
    DELETE FROM `player_wounds`
    WHERE `bleeding_level` = 0 AND `bandage_changes_needed` <= `bandage_changes_applied`;

    -- Archive old medical history (older than 30 days)
    DELETE FROM `medical_history`
    WHERE `timestamp` < DATE_SUB(NOW(), INTERVAL 30 DAY);
END$$
DELIMITER ;
