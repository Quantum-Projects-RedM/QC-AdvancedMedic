--=========================================================
-- QC-ADVANCED MEDIC - MEDICAL HELPERS
--=========================================================
-- Utility functions for medical system
-- Replaces client_shared.lua with proper export pattern
-- Version: 0.4.0 Simplified (global bleeding, no body parts)
--=========================================================

QCMed = QCMed or {}

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
-- BODY PART UTILITIES (For fracture system only)
--=========================================================

-- Get body part label for display (uses simplified labels table)
local function GetBodyPartLabel(bodyPart)
    if not bodyPart then return "Unknown" end
    return Config.BodyPartLabels[bodyPart] or bodyPart
end

--=========================================================
-- HEALTH CALCULATIONS (Simplified - global bleeding)
--=========================================================

-- Calculate bleeding damage per tick
local function CalculateBleedingDamage(bleedingLevel)
    if not bleedingLevel or bleedingLevel <= 0 then return 0 end

    local bleedTickDamage = Config.BleedTickDamage or 1
    return tonumber(bleedingLevel) * bleedTickDamage
end

-- Calculate overall player health status (simplified)
local function CalculateHealthStatus()
    local medicalState = QCMed.GetMedicalState()
    if not medicalState then
        return {
            bleedingLevel = 0,
            bandageChangesNeeded = 0,
            bandageChangesApplied = 0,
            status = "healthy"
        }
    end

    local bleedingLevel = medicalState.bleedingLevel or 0
    local bandageChangesNeeded = medicalState.bandageChangesNeeded or 0

    local status = "healthy"
    if bleedingLevel <= 0 and bandageChangesNeeded <= 0 then
        status = "healthy"
    elseif bleedingLevel >= 7 then
        status = "critical"
    elseif bleedingLevel >= 3 then
        status = "injured"
    else
        status = "minor_injuries"
    end

    return {
        bleedingLevel = bleedingLevel,
        bandageChangesNeeded = bandageChangesNeeded,
        bandageChangesApplied = medicalState.bandageChangesApplied or 0,
        status = status
    }
end

--=========================================================
-- TREATMENT UTILITIES (Simplified)
--=========================================================

-- Check if treatment is valid (global - no body parts)
local function IsValidTreatment(treatmentType)
    if not treatmentType then return false end

    local isWounded = QCMed.IsWounded()

    if treatmentType == "bandage" then
        if not isWounded then
            return false, "No active wounds to bandage"
        end

        local medicalState = QCMed.GetMedicalState()
        if medicalState.activeBandage then
            return false, "Bandage already applied"
        end
    elseif treatmentType == "tourniquet" then
        local medicalState = QCMed.GetMedicalState()
        if not medicalState.bleedingLevel or medicalState.bleedingLevel <= 0 then
            return false, "No bleeding requiring tourniquet"
        end

        if LocalPlayer.state.tourniquet and LocalPlayer.state.tourniquet > GetGameTimer() then
            return false, "Tourniquet already active"
        end
    end

    return true
end

-- Get active bandage status
local function GetActiveBandageStatus()
    local medicalState = QCMed.GetMedicalState()
    if not medicalState or not medicalState.activeBandage then
        return nil
    end

    local bandage = medicalState.activeBandage
    local currentTime = GetGameTimer()

    return {
        type = bandage.type,
        appliedTime = bandage.appliedTime,
        expirationTime = bandage.expirationTime,
        timeRemaining = bandage.expirationTime and (bandage.expirationTime - currentTime) / 1000 or 0,
        label = bandage.config and bandage.config.label or bandage.type,
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
-- STATE MANAGEMENT (Simplified)
--=========================================================

local StateKeys = {
    BLEEDING = 'medical_bleeding',
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

        local bleedingLevel = medicalData.bleedingLevel or 0
        StateManager.SetBleedingLevel(bleedingLevel, true)

        local status = bleedingLevel <= 0 and 'healthy' or (bleedingLevel > 7 and 'critical' or 'injured')
        StateManager.SetHealthStatus(status, true)

        return true
    end,

    ClearAllState = function()
        StateManager.SetBleedingLevel(0, true)
        StateManager.SetHealthStatus('healthy', true)
        return true
    end
}

--=========================================================
-- EXPORTS
--=========================================================

-- Medical helpers
QCMed.IsMedicJob = IsMedicJob
exports('IsMedicJob', IsMedicJob) -- Keep export for external resource access
QCMed.IsPlayerMedic = IsPlayerMedic
QCMed.GetBodyPartLabel = GetBodyPartLabel
QCMed.CalculateBleedingDamage = CalculateBleedingDamage
QCMed.CalculateHealthStatus = CalculateHealthStatus
QCMed.IsValidTreatment = IsValidTreatment
QCMed.GetActiveBandageStatus = GetActiveBandageStatus

-- Logger
QCMed.GetLogger = function() return Logger end
QCMed.Log = Logger

-- State manager
QCMed.GetStateManager = function() return StateManager end
QCMed.StateKeys = function() return StateKeys end

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
