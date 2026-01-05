--=========================================================
-- QC-ADVANCED MEDIC - DATABASE MIGRATION
-- Global Infection System Update
--=========================================================
-- This migration script updates from per-body-part infection tracking
-- to global infection level (0-100) tracking
--
-- BACKUP YOUR DATABASE BEFORE RUNNING THIS SCRIPT!
--
-- Run this script if you are upgrading from an older version
-- that used the player_infections table (per-body-part)
--=========================================================

-- Step 1: Rename old table as backup (if it exists)
-- This preserves your old data in case you need to rollback
RENAME TABLE IF EXISTS player_infections TO player_infections_backup;

-- Step 2: Create new global infection table
CREATE TABLE IF NOT EXISTS `player_infection` (
    `citizenid` VARCHAR(50) PRIMARY KEY,
    `infection_level` INT DEFAULT 0,
    `infection_stage` INT DEFAULT 0,
    `infection_sources` TEXT,
    `timestamp` BIGINT DEFAULT 0,
    `last_progress_check` BIGINT DEFAULT 0,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_infection_level` (`infection_level`),
    INDEX `idx_infection_stage` (`infection_stage`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Step 3: Migrate existing infection data (optional conversion)
-- This converts old per-body-part infections to global infection
-- Formula: Take highest stage infection and convert to level
-- Stage 1 = 15%, Stage 2 = 35%, Stage 3 = 65%, Stage 4 = 90%
INSERT INTO player_infection (citizenid, infection_level, infection_stage, infection_sources, timestamp, last_progress_check)
SELECT
    citizenid,
    CASE
        WHEN MAX(stage) = 1 THEN 15
        WHEN MAX(stage) = 2 THEN 35
        WHEN MAX(stage) = 3 THEN 65
        WHEN MAX(stage) = 4 THEN 90
        ELSE 0
    END AS infection_level,
    MAX(stage) AS infection_stage,
    JSON_OBJECT('migrated_from_old_system', COUNT(*)) AS infection_sources,
    UNIX_TIMESTAMP(MIN(start_time)) AS timestamp,
    UNIX_TIMESTAMP(MAX(last_progress_check)) AS last_progress_check
FROM player_infections_backup
WHERE is_active = 1
GROUP BY citizenid
ON DUPLICATE KEY UPDATE
    infection_level = VALUES(infection_level),
    infection_stage = VALUES(infection_stage),
    timestamp = VALUES(timestamp),
    last_progress_check = VALUES(last_progress_check);

--=========================================================
-- NOTES
--=========================================================
-- 1. The old player_infections table is renamed to player_infections_backup
--    You can drop it after verifying the migration worked: DROP TABLE player_infections_backup;
--
-- 2. The new table uses a single row per player instead of one row per body part
--
-- 3. infection_level is 0-100 (global infection percentage)
--    infection_stage is 0-4 (calculated from level)
--
-- 4. If you have no old infections to migrate, the INSERT will simply do nothing (no error)
--
-- 5. Stage mapping used for migration:
--    Old Stage 1 -> 15% global infection (Mild)
--    Old Stage 2 -> 35% global infection (Moderate)
--    Old Stage 3 -> 65% global infection (Severe)
--    Old Stage 4 -> 90% global infection (Critical)
--=========================================================

-- Optional: Drop the backup table after verifying migration
-- Uncomment the line below ONLY after verifying everything works
-- DROP TABLE IF EXISTS player_infections_backup;
