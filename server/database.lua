--=========================================================
-- QC-ADVANCED MEDIC - DATABASE INTEGRATION
--=========================================================
-- This file handles all database operations for the medical system
-- Provides persistent storage for wounds, treatments, infections, and medical history
-- Version: 0.4.0 Simplified (global bleeding + bandage cycles)
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
QCMedServer = QCMedServer or {}

--=========================================================
-- MEDICAL HISTORY LOGGING
--=========================================================

-- Log a medical event in the history
local function LogMedicalEvent(citizenid, eventType, bodyPart, details, performedBy)
    if not citizenid or not eventType then return false end

    local detailsJson = json.encode(details or {})

    MySQL.Async.execute([[
        INSERT INTO medical_history
        (citizenid, event_type, body_part, details, performed_by)
        VALUES (?, ?, ?, ?, ?)
    ]], {
        citizenid,
        eventType,
        bodyPart,
        detailsJson,
        performedBy
    })

    return true
end

--=========================================================
-- WOUND DATA PERSISTENCE (Simplified - global state)
--=========================================================

-- Save global medical state for a player (single row per player)
local function SaveWoundData(citizenid, medicalState)
    if not citizenid or not medicalState then return false end

    local metadataJson = json.encode({
        lastWoundSource = medicalState.lastWoundSource,
        woundTimestamp = medicalState.woundTimestamp,
    })

    MySQL.Async.execute([[
        INSERT INTO player_wounds
        (citizenid, bleeding_level, bandage_changes_needed, bandage_changes_applied, last_wound_source, metadata)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            bleeding_level = VALUES(bleeding_level),
            bandage_changes_needed = VALUES(bandage_changes_needed),
            bandage_changes_applied = VALUES(bandage_changes_applied),
            last_wound_source = VALUES(last_wound_source),
            metadata = VALUES(metadata),
            updated_at = CURRENT_TIMESTAMP
    ]], {
        citizenid,
        medicalState.bleedingLevel or 0,
        medicalState.bandageChangesNeeded or 0,
        medicalState.bandageChangesApplied or 0,
        medicalState.lastWoundSource,
        metadataJson
    })

    -- Log wound state change
    if (medicalState.bleedingLevel or 0) > 0 then
        LogMedicalEvent(citizenid, 'wound_created', nil, {
            bleedingLevel = medicalState.bleedingLevel,
            bandageChangesNeeded = medicalState.bandageChangesNeeded,
            lastWoundSource = medicalState.lastWoundSource
        })
    end

    return true
end

-- Load global medical state for a player
local function LoadWoundData(citizenid)
    if not citizenid then return {} end

    local result = MySQL.Sync.fetchAll('SELECT * FROM player_wounds WHERE citizenid = ?', {citizenid})

    if result and result[1] then
        local row = result[1]
        local metadata = {}
        if row.metadata then
            local success, decoded = pcall(json.decode, row.metadata)
            if success then metadata = decoded end
        end

        return {
            bleedingLevel = row.bleeding_level or 0,
            bandageChangesNeeded = row.bandage_changes_needed or 0,
            bandageChangesApplied = row.bandage_changes_applied or 0,
            lastWoundSource = row.last_wound_source,
            woundTimestamp = metadata.woundTimestamp or 0,
        }
    end

    return {}
end

-- Clear wound data for a player (admin clear / full heal)
local function ClearWoundData(citizenid)
    if not citizenid then return false end
    MySQL.Async.execute('DELETE FROM player_wounds WHERE citizenid = ?', {citizenid})
    LogMedicalEvent(citizenid, 'admin_clear_wounds', nil, { action = 'cleared_all' })
    return true
end

--=========================================================
-- TREATMENT DATA PERSISTENCE (Simplified - single active bandage)
--=========================================================

-- Save active bandage treatment for a player
local function SaveTreatmentData(citizenid, treatmentData)
    if not citizenid then return false end

    -- Mark all existing treatments as inactive
    MySQL.Async.execute('UPDATE medical_treatments SET is_active = 0 WHERE citizenid = ? AND is_active = 1', {citizenid})

    -- If there's an active bandage, save it
    if treatmentData and treatmentData.activeBandage then
        local bandage = treatmentData.activeBandage
        local metadata = json.encode({
            config = bandage.config,
        })

        -- Calculate expiration time as MySQL datetime
        local mysqlExpirationTime = nil
        if bandage.expirationTime and type(bandage.expirationTime) == 'number' then
            local currentGameTime = GetGameTimer()
            local secondsFromNow = (bandage.expirationTime - currentGameTime) / 1000
            if secondsFromNow > 0 and secondsFromNow < 86400 then
                local targetTime = os.time() + math.floor(secondsFromNow)
                mysqlExpirationTime = os.date('%Y-%m-%d %H:%M:%S', targetTime)
            end
        end

        MySQL.Async.execute([[
            INSERT INTO medical_treatments
            (citizenid, treatment_type, item_type, applied_by, expiration_time, bleeding_reduction, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ]], {
            citizenid,
            'bandage',
            bandage.type or 'cotton',
            bandage.appliedBy or citizenid,
            mysqlExpirationTime,
            bandage.config and bandage.config.bleedingReduction or 0,
            metadata
        })

        LogMedicalEvent(citizenid, 'bandage_applied', nil, {
            bandageType = bandage.type,
            appliedBy = bandage.appliedBy,
        }, bandage.appliedBy)
    end

    return true
end

-- Load active treatment data for a player
local function LoadTreatmentData(citizenid)
    if not citizenid then return {} end

    local result = MySQL.Sync.fetchAll('SELECT * FROM medical_treatments WHERE citizenid = ? AND is_active = 1 ORDER BY applied_time DESC LIMIT 1', {citizenid})

    if result and result[1] then
        local row = result[1]
        local metadata = {}
        if row.metadata then
            local success, decoded = pcall(json.decode, row.metadata)
            if success then metadata = decoded end
        end

        return {
            activeBandage = {
                type = row.item_type,
                appliedBy = row.applied_by,
                config = metadata.config,
            }
        }
    end

    return {}
end

--=========================================================
-- INFECTION DATA PERSISTENCE
--=========================================================

-- Save global infection data for a player (simplified global tracking)
local function SaveInfectionData(citizenid, infectionData)
    if not citizenid or not infectionData then return false end

    local sourcesJson = json.encode(infectionData.sources or {})

    MySQL.Async.execute([[
        INSERT INTO player_infection
        (citizenid, infection_level, infection_stage, infection_sources, timestamp, last_progress_check)
        VALUES (?, ?, ?, ?, FROM_UNIXTIME(?), FROM_UNIXTIME(?))
        ON DUPLICATE KEY UPDATE
            infection_level = VALUES(infection_level),
            infection_stage = VALUES(infection_stage),
            infection_sources = VALUES(infection_sources),
            timestamp = VALUES(timestamp),
            last_progress_check = VALUES(last_progress_check),
            updated_at = CURRENT_TIMESTAMP
    ]], {
        citizenid,
        infectionData.level or 0,
        infectionData.stage or 0,
        sourcesJson,
        math.floor((infectionData.timestamp or 0) / 1000),
        math.floor((infectionData.lastProgressCheck or 0) / 1000)
    })

    -- Log infection changes in medical history
    if infectionData.level > 0 then
        pcall(function()
            LogMedicalEvent(citizenid, 'infection_update', nil, {
                level = infectionData.level,
                stage = infectionData.stage,
                sources = infectionData.sources
            })
        end)
    end

    return true
end

-- Load global infection data for a player
local function LoadInfectionData(citizenid)
    if not citizenid then
        return { level = 0, stage = 0, sources = {}, timestamp = 0, lastProgressCheck = 0 }
    end

    local result = MySQL.Sync.fetchAll('SELECT * FROM player_infection WHERE citizenid = ?', {citizenid})

    if result and result[1] then
        local row = result[1]
        local sources = {}

        if row.infection_sources then
            local success, decoded = pcall(json.decode, row.infection_sources)
            if success then sources = decoded end
        end

        return {
            level = row.infection_level or 0,
            stage = row.infection_stage or 0,
            sources = sources,
            timestamp = (row.timestamp or 0) * 1000,
            lastProgressCheck = (row.last_progress_check or 0) * 1000
        }
    end

    return { level = 0, stage = 0, sources = {}, timestamp = 0, lastProgressCheck = 0 }
end

--=========================================================
-- MEDICAL HISTORY
--=========================================================

-- Get medical history for a player
local function GetMedicalHistory(citizenid, limit)
    if not citizenid then return {} end

    limit = limit or 50
    local result = MySQL.Sync.fetchAll([[
        SELECT * FROM medical_history
        WHERE citizenid = ?
        ORDER BY timestamp DESC
        LIMIT ?
    ]], {citizenid, limit})

    local history = {}
    for _, row in ipairs(result) do
        local details = {}
        if row.details then
            local success, decoded = pcall(json.decode, row.details)
            if success then details = decoded end
        end

        table.insert(history, {
            eventType = row.event_type,
            bodyPart = row.body_part,
            details = details,
            performedBy = row.performed_by,
            timestamp = row.timestamp
        })
    end

    return history
end

--=========================================================
-- COMPLETE MEDICAL PROFILE
--=========================================================

-- Get complete medical profile for a player
local function GetCompleteMedicalProfile(citizenid)
    if not citizenid then return {} end

    return {
        wounds = LoadWoundData(citizenid),
        treatments = LoadTreatmentData(citizenid),
        infections = LoadInfectionData(citizenid),
        history = GetMedicalHistory(citizenid, 20)
    }
end

--=========================================================
-- EXPORTS FOR SERVER USE
--=========================================================

QCMedServer.SaveWoundData = SaveWoundData
QCMedServer.LoadWoundData = LoadWoundData
QCMedServer.ClearWoundData = ClearWoundData
QCMedServer.SaveTreatmentData = SaveTreatmentData
QCMedServer.LoadTreatmentData = LoadTreatmentData
QCMedServer.SaveInfectionData = SaveInfectionData
QCMedServer.LoadInfectionData = LoadInfectionData
QCMedServer.LogMedicalEvent = LogMedicalEvent
QCMedServer.GetMedicalHistory = GetMedicalHistory
QCMedServer.GetCompleteMedicalProfile = GetCompleteMedicalProfile

--=========================================================
-- FRACTURE SYSTEM DATABASE FUNCTIONS
--=========================================================

-- Initialize fractures table
local function InitializeFracturesTable()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS player_fractures (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            body_part VARCHAR(20) NOT NULL,
            fracture_type ENUM('fracture', 'bone_break') NOT NULL,
            severity INT NOT NULL DEFAULT 5,
            pain_level FLOAT NOT NULL DEFAULT 0.0,
            mobility_impact FLOAT NOT NULL DEFAULT 0.0,
            healing_progress FLOAT NOT NULL DEFAULT 0.0,
            requires_surgery BOOLEAN DEFAULT FALSE,
            fracture_description TEXT,
            caused_by VARCHAR(50) DEFAULT 'fall',
            fall_height FLOAT DEFAULT 0.0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            healed_at TIMESTAMP NULL,
            INDEX(citizenid, body_part),
            INDEX(citizenid, healing_progress)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]], {}, function(result)
        if result then
            print('[QC-AdvancedMedic] player_fractures table initialized successfully')
        end
    end)
end

-- Save fracture to database
function SaveFracture(citizenid, bodyPart, fractureData)
    if not citizenid or not bodyPart or not fractureData then return false end

    MySQL.Async.execute([[
        INSERT INTO player_fractures
        (citizenid, body_part, fracture_type, severity, pain_level, mobility_impact, healing_progress,
         requires_surgery, fracture_description)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            fracture_type = VALUES(fracture_type),
            severity = VALUES(severity),
            pain_level = VALUES(pain_level),
            mobility_impact = VALUES(mobility_impact),
            healing_progress = VALUES(healing_progress),
            requires_surgery = VALUES(requires_surgery),
            fracture_description = VALUES(fracture_description),
            healed_at = NULL
    ]], {
        citizenid,
        bodyPart,
        fractureData.type or 'fracture',
        fractureData.severity or 5,
        fractureData.painLevel or 0.0,
        fractureData.mobilityImpact or 0.0,
        fractureData.healingProgress or 0.0,
        fractureData.requiresSurgery and 1 or 0,
        fractureData.description
    }, function(result)
        if result and result > 0 then
            LogMedicalEvent(citizenid, 'fracture_created', bodyPart, {
                fractureType = fractureData.type,
                severity = fractureData.severity,
                description = fractureData.description
            })
        end
    end)

    return true
end

-- Load fractures for a player
function LoadFractures(citizenid)
    if not citizenid then return {} end

    local result = MySQL.Sync.fetchAll([[
        SELECT * FROM player_fractures
        WHERE citizenid = ? AND healing_progress < 100.0
        ORDER BY created_at DESC
    ]], {citizenid})

    local fractures = {}
    for _, row in ipairs(result) do
        fractures[row.body_part] = {
            id = row.id,
            type = row.fracture_type,
            severity = row.severity,
            painLevel = row.pain_level,
            mobilityImpact = row.mobility_impact,
            healingProgress = row.healing_progress,
            requiresSurgery = row.requires_surgery == 1,
            description = row.fracture_description,
            timestamp = row.created_at
        }
    end

    return fractures
end

-- Heal fracture (mark as healed)
function HealFracture(citizenid, bodyPart)
    if not citizenid or not bodyPart then return false end

    MySQL.Async.execute([[
        UPDATE player_fractures
        SET healing_progress = 100.0, healed_at = NOW()
        WHERE citizenid = ? AND body_part = ? AND healing_progress < 100.0
    ]], {citizenid, bodyPart}, function(result)
        if result.affectedRows > 0 then
            LogMedicalEvent(citizenid, 'fracture_healed', bodyPart, {
                healingMethod = 'natural_healing'
            })
        end
    end)

    return true
end

-- Fracture module table entries
QCMedServer.SaveFractureData = SaveFracture
QCMedServer.LoadFractureData = LoadFractures
QCMedServer.SaveFracture = SaveFracture
QCMedServer.LoadFractures = LoadFractures
QCMedServer.HealFracture = HealFracture

--=========================================================
-- DATABASE CLEANUP FUNCTIONS
--=========================================================

-- Clean up expired data
local function CleanupExpiredData()
    pcall(function()
        MySQL.Async.execute('CALL CleanupExpiredMedicalData()')
        print('[QC-AdvancedMedic] Database cleanup completed')
    end)
end

-- Auto cleanup every hour
CreateThread(function()
    while true do
        Wait(3600000) -- 1 hour
        CleanupExpiredData()
    end
end)

-- Initialize table on server start
CreateThread(function()
    Wait(1000) -- Wait for database connection
    InitializeFracturesTable()
end)
