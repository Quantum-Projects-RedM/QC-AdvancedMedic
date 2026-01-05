--=========================================================
-- QC-ADVANCED MEDIC - SERVER VALIDATORS
--=========================================================
-- Centralized validation functions for server-authoritative operations
-- Consolidates IsMedicJob (defined 4x across 3 files) and player validation
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

--=========================================================
-- JOB VALIDATION
--=========================================================

-- Check if a job is a medic job (CONSOLIDATED - was defined 4 times)
local function IsMedicJob(jobName)
    if not jobName then return false end

    -- Check against all jobs in MedicJobLocations
    for _, location in pairs(Config.MedicJobLocations) do
        if location.job == jobName then
            return true
        end
    end

    return false
end

--=========================================================
-- PLAYER VALIDATION
--=========================================================

-- Validate player exists and has citizenid (used 20+ times across server files)
local function ValidatePlayer(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then
        return nil, "PLAYER_NOT_FOUND"
    end

    if not Player.PlayerData.citizenid then
        return nil, "NO_CITIZENID"
    end

    return Player
end

-- Validate player has medic job
local function ValidateMedic(source)
    local Player, err = ValidatePlayer(source)
    if not Player then
        return nil, err
    end

    if not IsMedicJob(Player.PlayerData.job.name) then
        return nil, "NOT_MEDIC"
    end

    return Player
end

--=========================================================
-- WOUND DATA VALIDATION
--=========================================================

-- Validate wound data structure
local function ValidateWoundData(woundData)
    if type(woundData) ~= "table" then
        return false, "INVALID_WOUND_DATA_TYPE"
    end

    for bodyPart, wound in pairs(woundData) do
        -- Check if body part exists in config
        if not Config.BodyParts[bodyPart] then
            return false, "INVALID_BODY_PART"
        end

        -- Validate pain level
        if wound.painLevel and (type(wound.painLevel) ~= "number" or wound.painLevel < 0) then
            return false, "INVALID_PAIN_LEVEL"
        end

        -- Validate bleeding level
        if wound.bleedingLevel and (type(wound.bleedingLevel) ~= "number" or wound.bleedingLevel < 0) then
            return false, "INVALID_BLEEDING_LEVEL"
        end
    end

    return true
end

--=========================================================
-- TREATMENT VALIDATION
--=========================================================

-- Validate treatment type and item
local function ValidateTreatment(treatmentType, itemType)
    if treatmentType == "bandage" then
        return Config.BandageTypes[itemType] ~= nil
    elseif treatmentType == "tourniquet" then
        return Config.TourniquetTypes and Config.TourniquetTypes[itemType] ~= nil
    elseif treatmentType == "medicine" then
        return Config.MedicineTypes and Config.MedicineTypes[itemType] ~= nil
    elseif treatmentType == "injection" then
        return Config.InjectionTypes and Config.InjectionTypes[itemType] ~= nil
    end

    return false
end

-- Validate body part supports limb-specific treatments
local function ValidateBodyPartForTreatment(bodyPart, treatmentType)
    local bodyPartConfig = Config.BodyParts[bodyPart]
    if not bodyPartConfig then
        return false, "INVALID_BODY_PART"
    end

    -- Tourniquets only work on limbs with arteries
    if treatmentType == "tourniquet" then
        if not bodyPartConfig.hasArtery then
            return false, "NO_ARTERY"
        end
    end

    return true
end

--=========================================================
-- INFECTION DATA VALIDATION
--=========================================================

-- Validate infection data structure
local function ValidateInfectionData(infectionData)
    if type(infectionData) ~= "table" then
        return false, "INVALID_INFECTION_DATA_TYPE"
    end

    for bodyPart, infection in pairs(infectionData) do
        -- Check if body part exists
        if not Config.BodyParts[bodyPart] then
            return false, "INVALID_BODY_PART"
        end

        -- Validate infection level
        if infection.infectionLevel and (type(infection.infectionLevel) ~= "number" or infection.infectionLevel < 0 or infection.infectionLevel > 100) then
            return false, "INVALID_INFECTION_LEVEL"
        end
    end

    return true
end

--=========================================================
-- DISTANCE VALIDATION
--=========================================================

-- Check if two players are within range
local function CheckDistance(source1, source2, maxDistance)
    local ped1 = GetPlayerPed(source1)
    local ped2 = GetPlayerPed(source2)

    if not ped1 or not ped2 then
        return false
    end

    local coords1 = GetEntityCoords(ped1)
    local coords2 = GetEntityCoords(ped2)
    local distance = #(coords1 - coords2)

    return distance <= maxDistance
end

--=========================================================
-- ITEM VALIDATION
--=========================================================

-- Check if player has required item
local function HasItem(source, itemName, amount)
    amount = amount or 1
    local Player, err = ValidatePlayer(source)
    if not Player then
        return false
    end

    local item = Player.Functions.GetItemByName(itemName)
    return item and item.amount >= amount
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
-- EXPORTS
--=========================================================

-- Validation helpers
exports('IsMedicJob', IsMedicJob)
exports('ValidatePlayer', ValidatePlayer)
exports('ValidateMedic', ValidateMedic)
exports('ValidateWoundData', ValidateWoundData)
exports('ValidateTreatment', ValidateTreatment)
exports('ValidateBodyPartForTreatment', ValidateBodyPartForTreatment)
exports('ValidateInfectionData', ValidateInfectionData)
exports('CheckDistance', CheckDistance)
exports('HasItem', HasItem)

-- Logger
exports('GetLogger', function() return Logger end)
exports('Log', Logger)

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

    Logger.Info("ServerValidators", "All validation helpers + logger loaded")
end)
