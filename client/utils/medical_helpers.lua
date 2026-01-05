--=========================================================
-- QC-ADVANCED MEDIC - MEDICAL HELPERS
--=========================================================
-- Utility functions for medical system
-- Replaces client_shared.lua with proper export pattern
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

--=========================================================
-- JOB VALIDATION
--=========================================================

-- Check if a job is a medic job
local function IsMedicJob(jobName)
    if not jobName then return false end

    for _, location in pairs(Config.MedicJobLocations or {}) do
        if location.job == jobName then
            return true
        end
    end

    return false
end

-- Check if player has medic job
local function IsPlayerMedic()
    local Player = RSGCore.Functions.GetPlayerData()
    if not Player or not Player.job then return false end

    return IsMedicJob(Player.job.name)
end

--=========================================================
-- BODY PART UTILITIES
--=========================================================

-- Get body part label for display
local function GetBodyPartLabel(bodyPart)
    if not bodyPart then return "Unknown" end

    local bodyPartConfig = Config.BodyParts[bodyPart]
    if bodyPartConfig and bodyPartConfig.label then
        return bodyPartConfig.label
    end

    return bodyPart
end

-- Get all body parts
local function GetAllBodyParts()
    local bodyParts = {}

    for bodyPart, config in pairs(Config.BodyParts or {}) do
        table.insert(bodyParts, {
            id = bodyPart,
            label = config.label or bodyPart,
            maxHealth = config.maxHealth or 100
        })
    end

    return bodyParts
end

--=========================================================
-- HEALTH CALCULATIONS
--=========================================================

-- Calculate bleeding damage per tick
local function CalculateBleedingDamage(bleedingLevel)
    if not bleedingLevel or bleedingLevel <= 0 then return 0 end

    local bleedTickDamage = Config.BleedTickDamage or 1
    return tonumber(bleedingLevel) * bleedTickDamage
end

-- Calculate overall player health status
local function CalculateHealthStatus()
    local wounds = exports['QC-AdvancedMedic']:GetMedicalState('wounds')
    if not wounds then
        return {
            totalPain = 0,
            totalBleeding = 0,
            woundCount = 0,
            criticalWounds = 0,
            status = "healthy"
        }
    end

    local totalPain = 0
    local totalBleeding = 0
    local woundCount = 0
    local criticalWounds = 0

    for bodyPart, wound in pairs(wounds) do
        if not wound.isScar then
            woundCount = woundCount + 1
            totalPain = totalPain + (wound.painLevel or 0)
            totalBleeding = totalBleeding + (wound.bleedingLevel or 0)

            if wound.severity and wound.severity >= 3 then
                criticalWounds = criticalWounds + 1
            end
        end
    end

    local status = "healthy"
    if woundCount == 0 then
        status = "healthy"
    elseif criticalWounds > 0 or totalBleeding > 15 then
        status = "critical"
    elseif woundCount > 2 or totalBleeding > 8 then
        status = "injured"
    else
        status = "minor_injuries"
    end

    return {
        totalPain = totalPain,
        totalBleeding = totalBleeding,
        woundCount = woundCount,
        criticalWounds = criticalWounds,
        status = status
    }
end

--=========================================================
-- TREATMENT UTILITIES
--=========================================================

-- Check if treatment is valid for body part
local function IsValidTreatment(bodyPart, treatmentType)
    if not bodyPart or not treatmentType then return false end

    local wounds = exports['QC-AdvancedMedic']:GetMedicalState('wounds')
    local wound = wounds and wounds[bodyPart]

    if not wound or wound.isScar then
        return false, "No active wound on this body part"
    end

    if treatmentType == "bandage" then
        if not wound.bleedingLevel or wound.bleedingLevel <= 0 then
            return false, "No bleeding to bandage"
        end

        local treatments = exports['QC-AdvancedMedic']:GetMedicalState('treatments')
        if treatments[bodyPart] and treatments[bodyPart].treatmentType == "bandage" then
            return false, "Bandage already applied"
        end
    elseif treatmentType == "tourniquet" then
        if not wound.bleedingLevel or wound.bleedingLevel <= 0 then
            return false, "No bleeding requiring tourniquet"
        end

        local treatments = exports['QC-AdvancedMedic']:GetMedicalState('treatments')
        if treatments[bodyPart] and treatments[bodyPart].treatmentType == "tourniquet" then
            return false, "Tourniquet already applied"
        end
    end

    return true
end

-- Get treatment status for body part
local function GetTreatmentStatus(bodyPart)
    if not bodyPart then return nil end

    local treatments = exports['QC-AdvancedMedic']:GetMedicalState('treatments')
    if not treatments or not treatments[bodyPart] then
        return nil
    end

    local treatment = treatments[bodyPart]
    local currentTime = GetGameTimer()

    return {
        type = treatment.treatmentType,
        itemType = treatment.itemType,
        appliedTime = treatment.appliedTime,
        expirationTime = treatment.expirationTime,
        timeRemaining = treatment.expirationTime and (treatment.expirationTime - currentTime) / 1000 or 0,
        isActive = treatment.isActive,
        effectiveness = treatment.effectiveness
    }
end

--=========================================================
-- STRUCTURED LOGGING (pattern)
--=========================================================

local LogLevels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4, TRACE = 5 }
local CurrentLogLevel = LogLevels.DEBUG
local LevelColors = { [1] = "^1", [2] = "^3", [3] = "^2", [4] = "^5", [5] = "^6" }
local LevelNames = { [1] = "ERROR", [2] = "WARN", [3] = "INFO", [4] = "DEBUG", [5] = "TRACE" }

local function Log(level, component, message, data)
    if level > CurrentLogLevel then return end

    local logMsg = string.format("%s[%s]^7 [^2%s^7] %s",
        LevelColors[level], LevelNames[level], component, message)

    if data then
        logMsg = logMsg .. string.format(" | %s", json.encode(data))
    end

    print(logMsg)
end

local Logger = {
    Error = function(component, msg, data) Log(LogLevels.ERROR, component, msg, data) end,
    Warn = function(component, msg, data) Log(LogLevels.WARN, component, msg, data) end,
    Info = function(component, msg, data) Log(LogLevels.INFO, component, msg, data) end,
    Debug = function(component, msg, data) Log(LogLevels.DEBUG, component, msg, data) end,
    Trace = function(component, msg, data) Log(LogLevels.TRACE, component, msg, data) end,
    SetLevel = function(levelName)
        local level = LogLevels[levelName]
        if level then CurrentLogLevel = level end
    end
}

--=========================================================
-- STATE MANAGEMENT (pattern - LocalPlayer.state)
--=========================================================

local StateKeys = {
    WOUNDS = 'medical_wounds',
    TREATMENTS = 'medical_treatments',
    BLEEDING = 'medical_bleeding',
    INFECTIONS = 'medical_infections',
    IS_INJURED = 'medical_is_injured',
    HEALTH_STATUS = 'medical_health_status'
}

local StateManager = {
    Set = function(key, value, replicate)
        LocalPlayer.state:set(key, value, replicate or false)
        return true
    end,

    Get = function(key)
        return LocalPlayer.state[key]
    end,

    SetWounds = function(wounds, replicate)
        return LocalPlayer.state:set(StateKeys.WOUNDS, wounds, replicate or false)
    end,

    GetWounds = function()
        return LocalPlayer.state[StateKeys.WOUNDS] or {}
    end,

    SetBleedingLevel = function(level, replicate)
        return LocalPlayer.state:set(StateKeys.BLEEDING, level, replicate or true)
    end,

    GetBleedingLevel = function()
        return LocalPlayer.state[StateKeys.BLEEDING] or 0
    end,

    SetHealthStatus = function(status, replicate)
        return LocalPlayer.state:set(StateKeys.HEALTH_STATUS, status, replicate or true)
    end,

    GetHealthStatus = function()
        return LocalPlayer.state[StateKeys.HEALTH_STATUS] or 'healthy'
    end,

    SaveAllState = function(medicalData)
        if not medicalData then return false end

        StateManager.SetWounds(medicalData.wounds or {}, false)

        local totalBleeding = 0
        local woundCount = 0
        for _, wound in pairs(medicalData.wounds or {}) do
            if not wound.isScar then
                woundCount = woundCount + 1
                totalBleeding = totalBleeding + (wound.bleedingLevel or 0)
            end
        end

        StateManager.SetBleedingLevel(totalBleeding, true)

        local status = woundCount == 0 and 'healthy' or (totalBleeding > 15 and 'critical' or 'injured')
        StateManager.SetHealthStatus(status, true)

        return true
    end,

    ClearAllState = function()
        StateManager.SetWounds({}, false)
        StateManager.SetBleedingLevel(0, true)
        StateManager.SetHealthStatus('healthy', true)
        return true
    end
}

--=========================================================
-- EXPORTS
--=========================================================

-- Medical helpers
exports('IsMedicJob', IsMedicJob)
exports('IsPlayerMedic', IsPlayerMedic)
exports('GetBodyPartLabel', GetBodyPartLabel)
exports('GetAllBodyParts', GetAllBodyParts)
exports('CalculateBleedingDamage', CalculateBleedingDamage)
exports('CalculateHealthStatus', CalculateHealthStatus)
exports('IsValidTreatment', IsValidTreatment)
exports('GetTreatmentStatus', GetTreatmentStatus)

-- Logger
exports('GetLogger', function() return Logger end)
exports('Log', Logger)

-- State manager
exports('GetStateManager', function() return StateManager end)
exports('StateKeys', function() return StateKeys end)

-- Backwards compatibility
IsMedicJob = IsMedicJob
GetBodyPartLabel = GetBodyPartLabel

--=========================================================
-- INITIALIZATION
--=========================================================

CreateThread(function()
    Wait(1000)

    -- Set log level from config
    if Config and Config.WoundSystem and Config.WoundSystem.debugging then
        if Config.WoundSystem.debugging.enabled then
            Logger.SetLevel("DEBUG")
        else
            Logger.SetLevel("INFO")
        end
    end

    Logger.Info("MedicalHelpers", "All utilities loaded (helpers + logger + state)")
end)
