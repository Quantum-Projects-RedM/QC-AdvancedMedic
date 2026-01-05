--=========================================================
-- QC-ADVANCED MEDIC - INFECTION SYSTEM
--=========================================================
-- This file handles the infection progression system based on Config.InfectionSystem
-- Manages dirty bandages, infection stages, and treatment outcomes
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

--=========================================================
-- GLOBAL INFECTION STATE (SIMPLIFIED)
--=========================================================
-- Single global infection level instead of per-body-part tracking
local GlobalInfection = {
    level = 0,            -- 0-100 infection level
    stage = 0,            -- 0-4 (0=none, 1=mild, 2=moderate, 3=severe, 4=critical)
    sources = {},         -- Track what caused infection { dirty_bandage = 2, untreated_wound = 1 }
    timestamp = 0,        -- When infection started
    lastProgressCheck = 0 -- Last time we checked for progression
}

-- Bandage effectiveness tracking (still per-body-part for wound management)
BandageTracker = {}

--=========================================================
-- INFECTION STAGE CALCULATION
--=========================================================
-- Calculate infection stage from level (0-100)
local function CalculateInfectionStage(level)
    if level == 0 then return 0 end
    if level <= 20 then return 1 end  -- Mild
    if level <= 50 then return 2 end  -- Moderate
    if level <= 80 then return 3 end  -- Severe
    return 4                          -- Critical
end

-- Get stage label for display
local function GetInfectionStageLabel(stage)
    local labels = {
        [0] = "None",
        [1] = "Mild",
        [2] = "Moderate",
        [3] = "Severe",
        [4] = "Critical"
    }
    return labels[stage] or "Unknown"
end

--=========================================================
-- GLOBAL INFECTION MANAGEMENT
--=========================================================

-- Add infection level to global infection
local function AddInfectionLevel(source, amount)
    if not Config.InfectionSystem.enabled then return end

    if GlobalInfection.level == 0 then
        -- Starting new infection
        GlobalInfection.timestamp = GetGameTimer()
        GlobalInfection.lastProgressCheck = GetGameTimer()
    end

    -- Add to infection level (capped at 100)
    GlobalInfection.level = math.min(GlobalInfection.level + amount, 100)

    -- Track source
    GlobalInfection.sources[source] = (GlobalInfection.sources[source] or 0) + 1

    -- Calculate new stage
    local oldStage = GlobalInfection.stage
    GlobalInfection.stage = CalculateInfectionStage(GlobalInfection.level)

    -- Show notification if stage changed
    if GlobalInfection.stage > oldStage and Config.InfectionSystem.stages[GlobalInfection.stage] then
        local stageConfig = Config.InfectionSystem.stages[GlobalInfection.stage]
        if stageConfig.symptom then
            lib.notify({
                title = "Infection Worsening",
                description = stageConfig.symptom,
                type = 'error',
                duration = 7000
            })
        end
    elseif GlobalInfection.stage == oldStage then
        -- Level increased but stage didn't change
        lib.notify({
            title = "Infection Level Increased",
            description = string.format("Infection: %d%% (%s)", GlobalInfection.level, GetInfectionStageLabel(GlobalInfection.stage)),
            type = 'warning',
            duration = 5000
        })
    end

    -- Save to server
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateInfectionData', GlobalInfection)

    if Config.InfectionSystem.debugging.enabled then
        print(string.format("^1[INFECTION] Level: %d%% | Stage: %d (%s) | Source: %s^7",
            GlobalInfection.level, GlobalInfection.stage, GetInfectionStageLabel(GlobalInfection.stage), source))
    end
end

-- Cure infection (reduce level)
local function CureInfection(cureAmount)
    if GlobalInfection.level == 0 then return false end

    GlobalInfection.level = math.max(GlobalInfection.level - cureAmount, 0)

    if GlobalInfection.level == 0 then
        -- Fully cured
        local oldStage = GlobalInfection.stage
        GlobalInfection.stage = 0
        GlobalInfection.sources = {}
        GlobalInfection.timestamp = 0

        -- Clear visual effects
        ClearTimecycleModifier()
        SetPedMoveRateOverride(cache.ped, 1.0)
        SetPlayerStaminaSprintDepletionMultiplier(PlayerId(), 1.0)

        lib.notify({
            title = "Infection Cured",
            description = "Your infection has been fully cured.",
            type = 'success',
            duration = 5000
        })

        if Config.InfectionSystem.debugging.enabled then
            print(string.format("^2[INFECTION] Fully cured (was stage %d)^7", oldStage))
        end
    else
        -- Partially cured
        local oldStage = GlobalInfection.stage
        GlobalInfection.stage = CalculateInfectionStage(GlobalInfection.level)

        -- Notify stage reduction if applicable
        if GlobalInfection.stage < oldStage then
            lib.notify({
                title = "Infection Improving",
                description = string.format("Infection reduced to %d%% (%s)", GlobalInfection.level, GetInfectionStageLabel(GlobalInfection.stage)),
                type = 'inform',
                duration = 5000
            })
        else
            lib.notify({
                title = "Treatment Applied",
                description = string.format("Infection: %d%% (%s)", GlobalInfection.level, GetInfectionStageLabel(GlobalInfection.stage)),
                type = 'inform',
                duration = 5000
            })
        end

        if Config.InfectionSystem.debugging.enabled then
            print(string.format("^3[INFECTION] Reduced to %d%% | Stage: %d (%s)^7",
                GlobalInfection.level, GlobalInfection.stage, GetInfectionStageLabel(GlobalInfection.stage)))
        end
    end

    -- Save to server
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateInfectionData', GlobalInfection)

    return true
end
--=========================================================
-- INFECTION DEVELOPMENT FROM DIRTY BANDAGES
--=========================================================
local function CheckForBandageInfection(bodyPart, bandageData, timeSinceExpiration)
    -- Calculate infection chance based on time since bandage expired
    local baseChance = Config.InfectionSystem.baseInfectionChance / 100 -- Convert percentage to decimal
    local totalChance = math.min(timeSinceExpiration * (baseChance / 10), baseChance) -- Build up over time

    -- Apply wound type multiplier if available
    local woundTypeMultiplier = 1.0
    if bandageData.metadata and bandageData.metadata.woundType then
        woundTypeMultiplier = Config.InfectionSystem.woundTypeMultipliers[bandageData.metadata.woundType] or
                             Config.InfectionSystem.woundTypeMultipliers.default
    end
    totalChance = totalChance * woundTypeMultiplier

    if Config.InfectionSystem.debugging.enabled and Config.InfectionSystem.debugging.printPercentages then
        print(string.format("^1[INFECTION] %s: %.1f%% chance (%.1fmin, %.1fx)^7",
            bodyPart, totalChance * 100, timeSinceExpiration, woundTypeMultiplier))
    end

    -- Roll for infection - add to global infection level
    if math.random() <= totalChance then
        -- Add infection level based on severity (15 points per dirty bandage)
        AddInfectionLevel("dirty_bandage", 15)

        -- Notify player
        lib.notify({
            title = "Infection Risk",
            description = string.format("Expired bandage on %s may cause infection!",
                Config.BodyParts[bodyPart] and Config.BodyParts[bodyPart].label or bodyPart),
            type = 'warning',
            duration = 5000
        })
    end
end
--=========================================================
-- BANDAGE EFFECTIVENESS DECAY SYSTEM
--=========================================================
local function UpdateBandageEffectiveness()
    local currentTime = GetGameTimer()
    
    for bodyPart, bandageData in pairs(BandageTracker) do
        -- Calculate if bandage has expired based on decayRate (minutes)
        local bandageConfig = Config.BandageTypes[bandageData.bandageType]
        if not bandageConfig then 
            -- Remove invalid bandage data
            BandageTracker[bodyPart] = nil
            goto continue
        end
        
        local expirationTime = bandageData.appliedTime + (bandageConfig.decayRate * 60 * 1000) -- Convert minutes to milliseconds
        local hasExpired = currentTime >= expirationTime
        
        -- If bandage has expired, check for infection development
        if hasExpired then
            local timeSinceExpiration = (currentTime - expirationTime) / 1000 / 60 -- Convert to minutes
            
            if timeSinceExpiration >= (Config.InfectionSystem.dirtyBandageGracePeriod / 60) then -- Convert seconds to minutes
                -- Check for infection development
                CheckForBandageInfection(bodyPart, bandageData, timeSinceExpiration)
            end
        end
        
        ::continue::
    end
end
--=========================================================
-- GLOBAL INFECTION EFFECTS APPLICATION
--=========================================================
local function ApplyInfectionEffects(stage)
    if stage == 0 then
        -- No infection - clear all effects
        SetPedMoveRateOverride(cache.ped, 1.0)
        SetPlayerStaminaSprintDepletionMultiplier(PlayerId(), 1.0)
        ClearTimecycleModifier()
        return
    end

    local stageConfig = Config.InfectionSystem.stages[stage]
    if not stageConfig or not stageConfig.effects then return end

    local ped = cache.ped
    local effects = stageConfig.effects

    -- Stage 1: Mild (health drain)
    if stage >= 1 then
        local currentHealth = GetEntityHealth(ped)
        if currentHealth > 100 then
            SetEntityHealth(ped, math.max(currentHealth - 1, 100))
        end
    end

    -- Stage 2: Moderate (slower movement)
    if stage >= 2 then
        SetPedMoveRateOverride(ped, 0.95)
    end

    -- Stage 3: Severe (visual effects + more movement penalty)
    if stage >= 3 then
        SetPedMoveRateOverride(ped, 0.90)
        -- Screen effects (blur, color grading)
        SetTimecycleModifier("MP_death_stagger")
    end

    -- Stage 4: Critical (heavy damage + severe penalties)
    if stage >= 4 then
        SetPedMoveRateOverride(ped, 0.85)
        local currentHealth = GetEntityHealth(ped)
        if currentHealth > 50 then
            SetEntityHealth(ped, math.max(currentHealth - 3, 50))
        end

        -- Persistent critical notification (every 60 seconds)
        local timeSinceStart = (GetGameTimer() - GlobalInfection.timestamp) / 1000
        if timeSinceStart % 60 < 5 then -- Show notification in first 5 seconds of each minute
            lib.notify({
                title = "Critical Infection!",
                description = "Your infection is life-threatening! Seek immediate medical attention!",
                type = 'error',
                duration = 10000
            })
        end
    end

    if Config.InfectionSystem.debugging.enabled then
        print(string.format("^1[INFECTION] Stage %d effects applied (level: %d%%)^7", stage, GlobalInfection.level))
    end
end
--=========================================================
-- GLOBAL INFECTION PROGRESSION SYSTEM
--=========================================================
local function ProcessInfectionProgression()
    if GlobalInfection.level == 0 then return end -- No active infection

    local currentTime = GetGameTimer()
    local timeSinceLastCheck = (currentTime - GlobalInfection.lastProgressCheck) / 1000 -- Convert to seconds

    -- Check if enough time has passed for progression check
    if timeSinceLastCheck >= (Config.InfectionSystem.progressionInterval / 1000) then
        GlobalInfection.lastProgressCheck = currentTime

        -- Increase infection level over time (2 points per interval by default)
        local progressionRate = Config.InfectionSystem.progressionRate or 2
        GlobalInfection.level = math.min(GlobalInfection.level + progressionRate, 100)

        -- Update stage
        local oldStage = GlobalInfection.stage
        GlobalInfection.stage = CalculateInfectionStage(GlobalInfection.level)

        -- Stage transition notification
        if GlobalInfection.stage > oldStage then
            local stageConfig = Config.InfectionSystem.stages[GlobalInfection.stage]
            if stageConfig and stageConfig.symptom then
                lib.notify({
                    title = "Infection Worsening",
                    description = string.format("%s (Stage %d: %s)",
                        stageConfig.symptom,
                        GlobalInfection.stage,
                        GetInfectionStageLabel(GlobalInfection.stage)),
                    type = 'error',
                    duration = 7000
                })
            end

            if Config.InfectionSystem.debugging.enabled then
                print(string.format("^1[INFECTION] Progressed to stage %d (%s) - Level: %d%%^7",
                    GlobalInfection.stage, GetInfectionStageLabel(GlobalInfection.stage), GlobalInfection.level))
            end
        end

        -- Save to server
        TriggerServerEvent('QC-AdvancedMedic:server:UpdateInfectionData', GlobalInfection)
    end

    -- Apply global effects
    ApplyInfectionEffects(GlobalInfection.stage)
end

--=========================================================
-- NOTE: TreatInfection function removed - now using global CureInfection
-- See CureInfection function above (lines 104-163)
--=========================================================

--=========================================================
-- MAIN UPDATE LOOPS
--=========================================================
CreateThread(function()
    while true do
        if Config.InfectionSystem.enabled then
            UpdateBandageEffectiveness()
        end
        Wait(60000) -- Update every minute
    end
end)

CreateThread(function()
    while true do
        if Config.InfectionSystem.enabled then
            ProcessInfectionProgression()
        end
        Wait(Config.InfectionSystem.checkInterval)
    end
end)

--=========================================================
-- EXPORTS FOR OTHER MODULES (GLOBAL INFECTION)
--=========================================================

-- Add bandage tracking (for dirty bandage detection)
exports('AddBandage', function(bodyPart, bandageType)
    local bandageConfig = Config.BandageTypes[bandageType]
    if not bandageConfig then return false end

    BandageTracker[bodyPart] = {
        bandageType = bandageType,
        appliedTime = GetGameTimer(),
        effectiveness = bandageConfig.effectiveness,
        decayRate = bandageConfig.decayRate,
        dirtyFactor = 0,
        lastUpdateTime = GetGameTimer()
    }

    return true
end)

-- Remove bandage tracking
exports('RemoveBandage', function(bodyPart)
    BandageTracker[bodyPart] = nil
end)

-- Get global infection data
exports('GetGlobalInfection', function()
    return GlobalInfection
end)

-- Get infection level (0-100)
exports('GetInfectionLevel', function()
    return GlobalInfection.level
end)

-- Get infection stage (0-4)
exports('GetInfectionStage', function()
    return GlobalInfection.stage
end)

-- Add infection level (source, amount)
exports('AddInfectionLevel', AddInfectionLevel)

-- Cure infection (reduce level)
exports('CureInfection', CureInfection)

-- Clear all infections
exports('ClearAllInfections', function()
    GlobalInfection = {
        level = 0,
        stage = 0,
        sources = {},
        timestamp = 0,
        lastProgressCheck = 0
    }
    BandageTracker = {}

    -- Clear all infection effects
    SetPlayerStaminaSprintDepletionMultiplier(PlayerId(), 1.0)
    
    if Config.InfectionSystem.debugging.enabled then
        print("[INFECTION] All infections cleared - effects reset")
    end
end)

-- Force create infection at specific level (for testing/debugging)
exports('CreateForceInfection', function(level)
    if not Config.InfectionSystem.enabled then return false end

    -- Validate level (0-100)
    level = math.max(0, math.min(100, level or 50))

    GlobalInfection.level = level
    GlobalInfection.stage = CalculateInfectionStage(level)
    GlobalInfection.timestamp = GetGameTimer()
    GlobalInfection.lastProgressCheck = GetGameTimer()
    GlobalInfection.sources = { forced = 1 }

    -- Show notification
    lib.notify({
        title = "Forced Infection",
        description = string.format("Infection set to %d%% (Stage %d: %s)",
            level, GlobalInfection.stage, GetInfectionStageLabel(GlobalInfection.stage)),
        type = 'warning',
        duration = 5000
    })

    -- Update server
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateInfectionData', GlobalInfection)

    if Config.InfectionSystem.debugging.enabled then
        print(string.format("^1[INFECTION] Forced to %d%% (Stage %d)^7", level, GlobalInfection.stage))
    end

    return true
end)

--=========================================================
-- NETWORK EVENTS (GLOBAL INFECTION)
--=========================================================

-- Sync global infection data from server
RegisterNetEvent('QC-AdvancedMedic:client:SyncInfectionData')
AddEventHandler('QC-AdvancedMedic:client:SyncInfectionData', function(infectionData)
    if infectionData then
        GlobalInfection = infectionData
    end
end)

-- Load global infection from database
RegisterNetEvent('QC-AdvancedMedic:client:LoadInfections')
AddEventHandler('QC-AdvancedMedic:client:LoadInfections', function(infectionData)
    if not infectionData then return end

    GlobalInfection = infectionData

    if Config.InfectionSystem.debugging.enabled then
        print(string.format("[PERSISTENCE] Loaded global infection: %d%% (Stage %d)",
            GlobalInfection.level, GlobalInfection.stage))
    end
end)

-- Use cure item (medicine/injection)
RegisterNetEvent('QC-AdvancedMedic:client:UseCureItem')
AddEventHandler('QC-AdvancedMedic:client:UseCureItem', function(cureType)
    local cureConfig = Config.InfectionSystem.cureItems[cureType]

    if not cureConfig then
        lib.notify({
            title = locale('cl_menu_treatment_error'),
            description = locale('cl_desc_unknown_cure_item'),
            type = 'error',
            duration = 5000
        })
        return
    end

    -- Check if player has infection
    if GlobalInfection.level == 0 then
        lib.notify({
            title = locale('cl_menu_no_infections'),
            description = locale('cl_desc_no_infections'),
            type = 'inform',
            duration = 5000
        })
        return
    end

    -- Start treatment animation/progress bar
    if lib.progressBar({
        duration = cureConfig.treatmentTime or 5000,
        label = string.format('Using %s...', cureConfig.label or cureType),
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'missheistdockssetup1clipboard@base',
            clip = 'base'
        }
    }) then
        -- Treatment completed - cure infection
        CureInfection(cureConfig.cureProgress or 30)
    else
        -- Treatment cancelled
        lib.notify({
            title = locale('cl_menu_treatment_cancelled'),
            description = locale('cl_desc_treatment_interrupted'),
            type = 'error',
            duration = 3000
        })
    end
end)

