--=========================================================
-- QC-ADVANCED MEDIC - DATABASE INTEGRATION
--=========================================================
-- This file handles all database operations for the medical system
-- Provides persistent storage for wounds, treatments, infections, and medical history
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

--=========================================================
-- MEDICAL HISTORY LOGGING (MOVED TO TOP FOR FUNCTION CALLS)
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
-- WOUND DATA PERSISTENCE
--=========================================================

-- Save or update wound data for a player
local function SaveWoundData(citizenid, woundData)
    if not citizenid or not woundData then return false end
    
    -- Insert/update current wounds (using UPSERT for accumulation)
    for bodyPart, wound in pairs(woundData) do
        local insertData = {
            citizenid = citizenid,
            body_part = bodyPart,
            pain_level = wound.painLevel or 0,
            bleeding_level = wound.bleedingLevel or 0,
            current_health = wound.currentHealth or 100.0,
            max_health = wound.maxHealth or 100.0,
            health_percentage = wound.healthPercentage or 100.0,
            weapon_data = wound.weaponData,
            weapon_hash = wound.metadata and wound.metadata.weaponHash,
            weapon_name = wound.metadata and wound.metadata.weaponName,
            damage_type = wound.metadata and wound.metadata.damageType,
            wound_description = wound.metadata and wound.metadata.description,
            is_scar = wound.isScar and 1 or 0,
            scar_time = wound.scarTime and os.date('%Y-%m-%d %H:%M:%S', math.floor(wound.scarTime / 1000)) or nil
        }
        
        MySQL.Async.execute([[
            INSERT INTO player_wounds 
            (citizenid, body_part, pain_level, bleeding_level, current_health, max_health, health_percentage, weapon_data, weapon_hash, weapon_name, damage_type, wound_description, is_scar, scar_time)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                pain_level = VALUES(pain_level),
                bleeding_level = VALUES(bleeding_level),
                current_health = VALUES(current_health),
                max_health = VALUES(max_health),
                health_percentage = VALUES(health_percentage),
                weapon_data = VALUES(weapon_data),
                weapon_hash = VALUES(weapon_hash),
                weapon_name = VALUES(weapon_name),
                damage_type = VALUES(damage_type),
                wound_description = VALUES(wound_description),
                is_scar = VALUES(is_scar),
                scar_time = VALUES(scar_time),
                updated_at = CURRENT_TIMESTAMP
        ]], {
            insertData.citizenid,
            insertData.body_part,
            insertData.pain_level,
            insertData.bleeding_level,
            insertData.current_health,
            insertData.max_health,
            insertData.health_percentage,
            insertData.weapon_data,
            insertData.weapon_hash,
            insertData.weapon_name,
            insertData.damage_type,
            insertData.wound_description,
            insertData.is_scar,
            insertData.scar_time
        })
        
        -- Log wound creation or scar conversion in medical history
        if wound.isScar and wound.scarTime then
            -- This is a scar conversion event
            LogMedicalEvent(citizenid, 'wound_scarred', bodyPart, {
                originalWound = wound.metadata and wound.metadata.description,
                weaponType = wound.weaponData,
                scarTime = wound.scarTime,
                healedFrom = {
                    painLevel = wound.painLevel,
                    bleedingLevel = wound.bleedingLevel
                }
            }, 'system')
        else
            -- This is a new wound creation
            LogMedicalEvent(citizenid, 'wound_created', bodyPart, {
                painLevel = wound.painLevel,
                bleedingLevel = wound.bleedingLevel,
                weaponType = wound.weaponData,
                description = wound.metadata and wound.metadata.description
            })
        end
    end
    
    return true
end

-- Load wound data for a player
local function LoadWoundData(citizenid)
    if not citizenid then return {} end
    
    local result = MySQL.Sync.fetchAll('SELECT * FROM player_wounds WHERE citizenid = ?', {citizenid})
    local woundData = {}
    
    for _, row in ipairs(result) do
        -- Convert scar timestamp from MySQL to client format (milliseconds)
        local scarTime = nil
        if row.scar_time then
            local year, month, day, hour, min, sec = string.match(row.scar_time, "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
            if year then
                scarTime = os.time({
                    year = tonumber(year),
                    month = tonumber(month),
                    day = tonumber(day),
                    hour = tonumber(hour),
                    min = tonumber(min),
                    sec = tonumber(sec)
                }) * 1000 -- Convert to milliseconds for client
            end
        end
        
        woundData[row.body_part] = {
            painLevel = row.pain_level,
            bleedingLevel = row.bleeding_level,
            currentHealth = row.current_health or 100.0,
            maxHealth = row.max_health or 100.0,
            healthPercentage = row.health_percentage or 100.0,
            weaponData = row.weapon_data,
            timestamp = row.created_at,
            isScar = row.is_scar == 1,
            scarTime = scarTime,
            metadata = {
                weaponHash = row.weapon_hash,
                weaponName = row.weapon_name,
                damageType = row.damage_type,
                description = row.wound_description,
                timestamp = row.created_at
            },
            treatments = {},
            infections = {}
        }
    end
    
    return woundData
end

-- Get player scars for medical records/NUI
local function GetPlayerScars(citizenid)
    if not citizenid then return {} end
    
    local result = MySQL.Sync.fetchAll([[
        SELECT body_part, weapon_data, weapon_name, damage_type, wound_description, 
               created_at as wound_date, scar_time,
               TIMESTAMPDIFF(DAY, scar_time, NOW()) as days_since_scarred
        FROM player_wounds 
        WHERE citizenid = ? AND is_scar = 1
        ORDER BY scar_time DESC
    ]], {citizenid})
    
    local scarData = {}
    for _, row in ipairs(result) do
        scarData[row.body_part] = {
            weaponType = row.weapon_data,
            weaponName = row.weapon_name,
            damageType = row.damage_type,
            originalWound = row.wound_description,
            woundDate = row.wound_date,
            scarTime = row.scar_time,
            daysSinceScarred = row.days_since_scarred
        }
    end
    
    return scarData
end

--=========================================================
-- TREATMENT DATA PERSISTENCE
--=========================================================

-- Save treatment data for a player (optimized for consolidated treatments table)
local function SaveTreatmentData(citizenid, treatmentData)
    if not citizenid or not treatmentData then return false end
    
    -- Mark all existing treatments as inactive
    MySQL.Async.execute('UPDATE medical_treatments SET is_active = 0 WHERE citizenid = ? AND is_active = 1', {citizenid})
    
    -- Insert current active treatments (supports all treatment types)
    for bodyPart, treatment in pairs(treatmentData) do
        local metadata = json.encode(treatment.metadata or {})
        
        -- Convert game timer to proper MySQL datetime if expirationTime exists
        local mysqlExpirationTime = nil
        if treatment.expirationTime and type(treatment.expirationTime) == 'number' then
            -- Calculate seconds from now based on game timer difference
            local currentGameTime = GetGameTimer()
            local secondsFromNow = (treatment.expirationTime - currentGameTime) / 1000
            
            -- Validate the calculated time is reasonable (within 24 hours)
            if secondsFromNow and secondsFromNow > 0 and secondsFromNow < 86400 then
                local targetTime = os.time() + math.floor(secondsFromNow)
                mysqlExpirationTime = os.date('%Y-%m-%d %H:%M:%S', targetTime)
            end
        end
        
        MySQL.Async.execute([[
            INSERT INTO medical_treatments 
            (citizenid, body_part, treatment_type, item_type, applied_by, expiration_time, duration, 
             original_pain_level, original_bleeding_level, pain_reduction, bleeding_reduction, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            citizenid,
            bodyPart,
            treatment.treatmentType or 'bandage',
            treatment.itemType or 'cotton_bandage',
            treatment.appliedBy or citizenid, -- Default to self if not specified
            mysqlExpirationTime, -- Properly formatted MySQL datetime
            treatment.duration, -- NULL for bandages, seconds for medicines
            treatment.originalPainLevel, -- Original pain before treatment
            treatment.originalBleedingLevel, -- Original bleeding before treatment
            treatment.painReduction, -- How much pain was reduced
            treatment.bleedingReduction, -- How much bleeding was reduced
            metadata
        })
        
        -- Log treatment application in medical history
        LogMedicalEvent(citizenid, 'treatment_applied', bodyPart, {
            treatmentType = treatment.treatmentType,
            itemType = treatment.itemType,
            appliedBy = treatment.appliedBy,
            effectiveness = treatment.effectiveness
        }, treatment.appliedBy)
    end
    
    return true
end

-- Load treatment data for a player
local function LoadTreatmentData(citizenid)
    if not citizenid then return {} end
    
    local result = MySQL.Sync.fetchAll('SELECT * FROM medical_treatments WHERE citizenid = ? AND is_active = 1', {citizenid})
    local treatmentData = {}
    
    for _, row in ipairs(result) do
        local metadata = {}
        if row.metadata then
            local success, decoded = pcall(json.decode, row.metadata)
            if success then
                metadata = decoded
            end
        end
        
        treatmentData[row.body_part] = {
            treatmentType = row.treatment_type,
            itemType = row.item_type,
            appliedTime = row.applied_time,
            expirationTime = row.expiration_time,
            duration = row.duration,
            appliedBy = row.applied_by,
            originalPainLevel = row.original_pain_level,
            originalBleedingLevel = row.original_bleeding_level,
            painReduction = row.pain_reduction,
            bleedingReduction = row.bleeding_reduction,
            isActive = row.is_active == 1,
            metadata = metadata
        }
    end
    
    return treatmentData
end

--=========================================================
-- INFECTION DATA PERSISTENCE
--=========================================================

-- Save infection data for a player (optimized with immunity tracking)
local function SaveInfectionData(citizenid, infectionData)
    if not citizenid or not infectionData then return false end
    
    -- Mark all existing infections as inactive
    MySQL.Async.execute('UPDATE player_infections SET is_active = 0 WHERE citizenid = ? AND is_active = 1', {citizenid})
    
    -- Insert current active infections (with consolidated immunity data)
    for bodyPart, infection in pairs(infectionData) do
        local metadata = json.encode(infection.metadata or {})
        
        MySQL.Async.execute([[
            INSERT INTO player_infections 
            (citizenid, body_part, infection_type, category, stage, start_time, last_progress_check, metadata)
            VALUES (?, ?, ?, ?, ?, FROM_UNIXTIME(?), FROM_UNIXTIME(?), ?)
            ON DUPLICATE KEY UPDATE
                stage = VALUES(stage),
                last_progress_check = VALUES(last_progress_check),
                metadata = VALUES(metadata)
        ]], {
            citizenid,
            bodyPart,
            'bandage_infection',  -- Always bandage infection in simplified system
            'dirtyBandage',       -- Always dirty bandage category
            infection.stage,
            math.floor(infection.startTime / 1000), -- Convert from GetGameTimer() to unix timestamp
            math.floor(infection.lastProgressCheck / 1000),
            metadata
        })
        
        -- Log infection creation in medical history (only if tables exist)
        pcall(function()
            LogMedicalEvent(citizenid, 'infection_started', bodyPart, {
                stage = infection.stage,
                cause = infection.metadata and infection.metadata.causeDescription
            })
        end)
    end
    
    return true
end

-- Load infection data for a player
local function LoadInfectionData(citizenid)
    if not citizenid then return {} end
    
    local result = MySQL.Sync.fetchAll('SELECT * FROM player_infections WHERE citizenid = ? AND is_active = 1', {citizenid})
    local infectionData = {}
    
    for _, row in ipairs(result) do
        local metadata = {}
        
        if row.metadata then
            local success, decoded = pcall(json.decode, row.metadata)
            if success then metadata = decoded end
        end
        
        infectionData[row.body_part] = {
            stage = row.stage,
            startTime = (row.start_time * 1000), -- Convert unix timestamp to GetGameTimer() format
            lastProgressCheck = (row.last_progress_check * 1000),
            metadata = metadata
        }
    end
    
    return infectionData
end

--=========================================================
-- BANDAGE TRACKING (Now integrated with medical_treatments)
--=========================================================
-- NOTE: Bandages are now stored in the medical_treatments table
-- Use SaveTreatmentData() with treatment_type = 'bandage'


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
-- SCAR SYSTEM
--=========================================================

-- Create a scar when wound heals
local function CreateScar(citizenid, bodyPart, woundData)
    if not citizenid or not bodyPart or not woundData then return false end
    
    -- Determine scar severity based on wound data
    local severity = "minor"
    if woundData.painLevel >= 8 then
        severity = "severe"
    elseif woundData.painLevel >= 6 then
        severity = "major"
    elseif woundData.painLevel >= 4 then
        severity = "moderate"
    end
    
    -- Only create scars for significant wounds (pain level 3+)
    if woundData.painLevel >= 3 then
        MySQL.Async.execute([[
            UPDATE player_wounds 
            SET is_scar = 1, scar_time = NOW(), wound_description = ?
            WHERE citizenid = ? AND body_part = ?
        ]], {
            woundData.metadata and woundData.metadata.description or 'Old injury',
            citizenid,
            bodyPart
        })
        
        -- Log scar creation
        LogMedicalEvent(citizenid, 'wound_healed', bodyPart, {
            scarSeverity = severity,
            originalPainLevel = woundData.painLevel,
            weaponType = woundData.weaponData
        })
    end
    
    return true
end

-- Get scars for a player
local function GetPlayerScars(citizenid)
    if not citizenid then return {} end
    
    local result = MySQL.Sync.fetchAll('SELECT * FROM player_wounds WHERE citizenid = ? AND is_scar = 1', {citizenid})
    local scars = {}
    
    for _, row in ipairs(result) do
        table.insert(scars, {
            bodyPart = row.body_part,
            scarType = row.damage_type or 'unknown',
            description = row.wound_description or 'Old injury',
            severity = row.pain_level,
            weaponType = row.weapon_data or 'unknown',
            originalWoundDate = row.created_at,
            healedDate = row.scar_time
        })
    end
    
    return scars
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
        scars = GetPlayerScars(citizenid),
        history = GetMedicalHistory(citizenid, 20)
    }
end

--=========================================================
-- MEDICAL INSPECTION LOGGING
--=========================================================

-- Log a medical inspection
local function LogMedicalInspection(patientId, medicId, inspectionType, findings, treatments)
    if not patientId or not medicId then return false end
    
    local findingsJson = json.encode(findings or {})
    local treatmentsRecommended = json.encode(treatments and treatments.recommended or {})
    local treatmentsApplied = json.encode(treatments and treatments.applied or {})
    
    MySQL.Async.execute([[
        INSERT INTO medical_inspections 
        (patient_citizenid, medic_citizenid, inspection_type, findings, treatments_recommended, treatments_applied)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        patientId,
        medicId,
        inspectionType or 'basic',
        findingsJson,
        treatmentsRecommended,
        treatmentsApplied
    })
    
    return true
end

--=========================================================
-- EXPORTS FOR SERVER USE
--=========================================================

-- Optimized exports for 3-table schema
exports('SaveWoundData', SaveWoundData)
exports('LoadWoundData', LoadWoundData)
exports('GetPlayerScars', GetPlayerScars)
exports('SaveTreatmentData', SaveTreatmentData) -- Now handles bandages, medicines, tourniquets, injections
exports('LoadTreatmentData', LoadTreatmentData)
exports('SaveInfectionData', SaveInfectionData) -- Now includes immunity tracking
exports('LoadInfectionData', LoadInfectionData)
exports('LogMedicalEvent', LogMedicalEvent)
exports('GetMedicalHistory', GetMedicalHistory)
exports('CreateScar', CreateScar)
exports('GetCompleteMedicalProfile', GetCompleteMedicalProfile)
exports('LogMedicalInspection', LogMedicalInspection)

-- Legacy compatibility (deprecated - use SaveTreatmentData instead)
exports('SaveBandageData', function(citizenid, bandageData)
    -- Convert bandage data to treatment data format
    local treatmentData = {}
    for bodyPart, bandage in pairs(bandageData or {}) do
        treatmentData[bodyPart] = {
            treatmentType = 'bandage',
            itemType = bandage.bandageType or 'cotton_bandage',
            appliedBy = citizenid,
            effectiveness = bandage.effectiveness or 100.0,
            decayRate = bandage.decayRate or 0.0,
            dirtyFactor = bandage.dirtyFactor or 0.0,
            appliedTime = bandage.appliedTime,
            metadata = bandage.metadata or {}
        }
    end
    return SaveTreatmentData(citizenid, treatmentData)
end)

--=========================================================
-- DATABASE CLEANUP FUNCTIONS
--=========================================================

-- Clean up expired data
local function CleanupExpiredData()
    -- This calls the stored procedure created in schema.sql
    MySQL.Async.execute('CALL CleanupExpiredMedicalData()')
    print('[QC-AdvancedMedic] Database cleanup completed')
end

-- Auto cleanup every hour
CreateThread(function()
    while true do
        Wait(3600000) -- 1 hour
        CleanupExpiredData()
    end
end)

--=========================================================
-- FRACTURE SYSTEM DATABASE FUNCTIONS
--=========================================================

-- Initialize fractures table (run this manually or add to schema.sql)
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
        else
            print('[QC-AdvancedMedic] Failed to initialize player_fractures table')
        end
    end)
end

-- Save fracture to database
function SaveFracture(citizenid, bodyPart, fractureData)
    if not citizenid or not bodyPart or not fractureData then 
        print('[QC-AdvancedMedic] SaveFracture: Missing required parameters')
        return false 
    end
    
    local insertData = {
        citizenid = citizenid,
        body_part = bodyPart,
        fracture_type = fractureData.type or 'fracture',
        severity = fractureData.severity or 5,
        pain_level = fractureData.painLevel or 0.0,
        mobility_impact = fractureData.mobilityImpact or 0.0,
        healing_progress = fractureData.healingProgress or 0.0,
        requires_surgery = fractureData.requiresSurgery and 1 or 0,
        fracture_description = fractureData.description
    }
    
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
        insertData.citizenid,
        insertData.body_part,
        insertData.fracture_type,
        insertData.severity,
        insertData.pain_level,
        insertData.mobility_impact,
        insertData.healing_progress,
        insertData.requires_surgery,
        insertData.fracture_description
    }, function(result)
        if result and result > 0 then
            LogMedicalEvent(citizenid, 'fracture_created', bodyPart, {
                fractureType = insertData.fracture_type,
                severity = insertData.severity,
                description = insertData.fracture_description
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

-- Initialize table on server start
CreateThread(function()
    Wait(1000) -- Wait for database connection
    InitializeFracturesTable()
end)