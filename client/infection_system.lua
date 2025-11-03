--=========================================================
-- QC-ADVANCED MEDIC - INFECTION SYSTEM
--=========================================================
-- This file handles the infection progression system based on Config.InfectionSystem
-- Manages dirty bandages, infection stages, and treatment outcomes
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- Infection tracking data
PlayerInfections = {}
BandageTracker = {} -- Tracks bandage effectiveness and dirty factor over time
local InfectionImmunity = {} -- Tracks temporary immunity from treatments
InfectionCureProgress = {} -- Tracks gradual cure progress (0-100%)

--=========================================================
-- INFECTION DATA STRUCTURE (SIMPLIFIED)
--=========================================================
-- PlayerInfections[bodyPart] = {
--     stage = 1,                          -- Current infection stage (1-4)
--     startTime = GetGameTimer(),          -- When infection started
--     lastProgressCheck = GetGameTimer(),  -- When last checked for progression
--     metadata = {
--         causeDescription = "Dirty bandage infection",
--         symptoms = {},
--         treatments = {}
--     }
-- }
--
-- InfectionCureProgress[bodyPart] = 0.0   -- Cure progress (0-100%)

--=========================================================
-- BANDAGE EFFECTIVENESS TRACKING
--=========================================================
-- BandageTracker[bodyPart] = {
--     bandageType = "cotton",
--     appliedTime = os.time(),
--     effectiveness = 80, -- Current effectiveness (0-100)
--     decayRate = 1.5, -- From Config.BandageTypes
--     dirtyFactor = 0, -- Accumulates when effectiveness hits 0
--     lastUpdateTime = os.time()
-- }

--=========================================================
-- INFECTION SYMPTOM DISPLAY
--=========================================================
local function ShowInfectionSymptom(bodyPart, stage)
    local infection = PlayerInfections[bodyPart]
    if not infection then return end
    
    local stageConfig = Config.InfectionSystem.stages[stage]
    
    if stageConfig and stageConfig.symptom then
        lib.notify({
            title = "Medical Condition",
            description = stageConfig.symptom,
            type = 'inform',
            duration = 6000
        })
    end
end

--=========================================================
-- INFECTION CREATION & MANAGEMENT
--=========================================================
local function CreateInfection(bodyPart)
    if not Config.InfectionSystem.enabled then return end
    
    PlayerInfections[bodyPart] = {
        stage = 1,
        startTime = GetGameTimer(),
        lastProgressCheck = GetGameTimer(),
        metadata = {
            causeDescription = "Infection from dirty bandage",
            symptoms = {Config.InfectionSystem.stages[1].symptom},
            treatments = {}
        }
    }
    
    -- Initialize cure progress
    InfectionCureProgress[bodyPart] = 0.0
    
    -- Show initial symptom
    ShowInfectionSymptom(bodyPart, 1)
    
    -- Update server
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateInfectionData', PlayerInfections)
    
    if Config.InfectionSystem.debugging.enabled then
        print(string.format("^1[INFECTION] Created on %s^7", bodyPart))
    end
end
--=========================================================
-- INFECTION DEVELOPMENT FROM DIRTY BANDAGES
--=========================================================
local function CheckForBandageInfection(bodyPart, bandageData, timeSinceExpiration)
    if PlayerInfections[bodyPart] then return end -- Already infected
    if InfectionImmunity[bodyPart] and InfectionImmunity[bodyPart] > GetGameTimer() then return end -- Immune
    
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
    
    -- Roll for infection
    if math.random() <= totalChance then
        CreateInfection(bodyPart)
        
        -- Notify player
        lib.notify({
            title = Config.InfectionSystem.notifications.infectionStart.title,
            description = string.format("Your expired %s bandage has caused an infection!", 
                Config.BodyParts[bodyPart] and Config.BodyParts[bodyPart].label or bodyPart),
            type = Config.InfectionSystem.notifications.infectionStart.type,
            duration = Config.InfectionSystem.notifications.infectionStart.duration
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
-- INFECTION EFFECTS APPLICATION
--=========================================================
local function ApplyInfectionEffects(bodyPart, infection)
    local stageConfig = Config.InfectionSystem.stages[infection.stage]
    
    if not stageConfig or not stageConfig.effects then return end
    
    local ped = PlayerPedId()
    local effects = stageConfig.effects
    
    -- Health damage removed - infections now focus on immersive effects only
    
    -- Apply stamina drain by making stamina deplete faster
    if effects.staminaDrain and effects.staminaDrain > 0 then
        local playerId = PlayerId()
        local currentStamina = GetPlayerStamina(playerId)
        -- Make stamina drain faster based on infection severity
        local multiplier = 1.0 + (effects.staminaDrain / 50.0) -- More reasonable multiplier
        SetPlayerStaminaSprintDepletionMultiplier(playerId, multiplier)
        
        if Config.InfectionSystem.debugging.enabled then
            print(string.format("^1[INFECTION] %s: stage%d stamina %.2fx^7", 
                bodyPart, infection.stage, multiplier))
        end
    end
    
    -- Apply movement penalty
    if effects.movementPenalty and effects.movementPenalty > 0 then
        local moveRate = 1.0 - (effects.movementPenalty / 100)
        local finalMoveRate = math.max(moveRate, 0.2)
        SetPedMoveRateOverride(ped, finalMoveRate)
        
        if Config.InfectionSystem.debugging.enabled then
            print(string.format("^1[INFECTION] %s: stage%d movement %.2fx^7", 
                bodyPart, infection.stage, finalMoveRate))
        end
    end
    
    -- Apply temperature change (fever/chills) - RedM compatible
    if effects.temperatureChange and effects.temperatureChange > 0 then
        -- For now, just track temperature for debugging (visual effects can be added later)
        if Config.InfectionSystem.debugging.enabled then
            print(string.format("^1[INFECTION] %s: stage%d fever %.1f°^7", 
                bodyPart, infection.stage, effects.temperatureChange))
        end
        
        -- TODO: Add RedM-compatible visual effects here in the future
        -- Examples: screen tinting, blur effects, or other RedM-supported visuals
    end
end
--=========================================================
-- INFECTION PROGRESSION SYSTEM
--=========================================================
local function ProcessInfectionProgression()
    local currentTime = GetGameTimer()
    
    for bodyPart, infection in pairs(PlayerInfections) do
        local stageConfig = Config.InfectionSystem.stages[infection.stage]
        
        if not stageConfig then
            goto continue
        end
        
        local timeSinceLastCheck = (currentTime - infection.lastProgressCheck) / 1000 -- Convert to seconds
        
        -- Check if enough time has passed for progression check (convert ms to seconds)
        if timeSinceLastCheck >= (Config.InfectionSystem.progressionInterval / 1000) then
            infection.lastProgressCheck = currentTime
            
            -- Roll for progression
            if math.random() <= stageConfig.progressionChance and infection.stage < #Config.InfectionSystem.stages then
                infection.stage = infection.stage + 1
                
                -- Show new symptom
                ShowInfectionSymptom(bodyPart, infection.stage)
                
                -- Add to symptom history
                local newSymptom = Config.InfectionSystem.stages[infection.stage].symptom
                table.insert(infection.metadata.symptoms, newSymptom)
                
                -- Notify of progression
                lib.notify({
                    title = Config.InfectionSystem.notifications.infectionProgression.title,
                    description = newSymptom,
                    type = Config.InfectionSystem.notifications.infectionProgression.type,
                    duration = Config.InfectionSystem.notifications.infectionProgression.duration
                })
                
                if Config.InfectionSystem.debugging.enabled and Config.InfectionSystem.debugging.printProgression then
                    print(string.format("[INFECTION] %s infection progressed to stage %d", bodyPart, infection.stage))
                end
            end
        end
        
        -- Apply stage effects
        ApplyInfectionEffects(bodyPart, infection)
        
        ::continue::
    end
end

--=========================================================
-- INFECTION TREATMENT SYSTEM - GRADUAL CURE
--=========================================================
local function TreatInfection(bodyPart, treatmentItem)
    if not PlayerInfections[bodyPart] then return false end
    
    local infection = PlayerInfections[bodyPart]
    local treatmentConfig = Config.InfectionSystem.cureItems[treatmentItem]
    
    if not treatmentConfig then
        lib.notify({
            title = "Treatment Failed",
            description = string.format("Unknown treatment item: %s", treatmentItem),
            type = 'error',
            duration = 5000
        })
        return false
    end
    
    -- Initialize cure progress if not exists
    if not InfectionCureProgress[bodyPart] then
        InfectionCureProgress[bodyPart] = 0.0
    end
    
    -- Add cure progress
    local oldProgress = InfectionCureProgress[bodyPart]
    InfectionCureProgress[bodyPart] = math.min(InfectionCureProgress[bodyPart] + treatmentConfig.cureProgress, 100.0)
    
    -- Record treatment
    table.insert(infection.metadata.treatments, {
        item = treatmentItem,
        progress = treatmentConfig.cureProgress,
        timestamp = GetGameTimer()
    })
    
    if Config.InfectionSystem.debugging.enabled and Config.InfectionSystem.debugging.printCureProgress then
        print(string.format("^3[CURE] %s: %.1f%%→%.1f%% (%s)^7", 
            bodyPart, oldProgress, InfectionCureProgress[bodyPart], treatmentItem))
    end
    
    -- Check if infection is cured
    if InfectionCureProgress[bodyPart] >= 100.0 then
        -- Cure successful
        PlayerInfections[bodyPart] = nil
        InfectionCureProgress[bodyPart] = nil
        
        -- Reset stamina multiplier to normal
        SetPlayerStaminaSprintDepletionMultiplier(PlayerId(), 1.0)
        
        if Config.InfectionSystem.debugging.enabled then
            print(string.format("[INFECTION] %s infection cured - effects cleared", bodyPart))
        end
        
        -- Grant temporary immunity
        if treatmentConfig.preventReinfection and treatmentConfig.preventReinfection > 0 then
            InfectionImmunity[bodyPart] = GetGameTimer() + (treatmentConfig.preventReinfection * 1000)
        end
        
        -- Notify success
        lib.notify({
            title = Config.InfectionSystem.notifications.infectionCured.title,
            description = string.format("The infection in your %s has been cured!", 
                Config.BodyParts[bodyPart] and Config.BodyParts[bodyPart].label or bodyPart),
            type = Config.InfectionSystem.notifications.infectionCured.type,
            duration = Config.InfectionSystem.notifications.infectionCured.duration
        })
        
        -- Update server
        TriggerServerEvent('QC-AdvancedMedic:server:UpdateInfectionData', PlayerInfections)
        
        -- Log cure event
        TriggerServerEvent('QC-AdvancedMedic:server:LogInfectionCure', bodyPart, treatmentItem)
        
        return true
    else
        -- Treatment applied but not fully cured yet
        local remainingProgress = 100.0 - InfectionCureProgress[bodyPart]
        local estimatedTreatments = math.ceil(remainingProgress / treatmentConfig.cureProgress)
        
        lib.notify({
            title = "Treatment Applied",
            description = string.format("Infection cure progress: %.1f%% (estimated %d more treatments needed)", 
                InfectionCureProgress[bodyPart], estimatedTreatments),
            type = 'inform',
            duration = 6000
        })
        
        return true
    end
end

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
-- EXPORTS FOR OTHER MODULES
--=========================================================
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

exports('RemoveBandage', function(bodyPart)
    BandageTracker[bodyPart] = nil
end)

exports('GetInfectionData', function(bodyPart)
    return bodyPart and PlayerInfections[bodyPart] or PlayerInfections
end)

exports('TreatInfection', function(bodyPart, treatmentItem)
    return TreatInfection(bodyPart, treatmentItem)
end)

exports('ClearAllInfections', function()
    PlayerInfections = {}
    BandageTracker = {}
    InfectionImmunity = {}
    InfectionCureProgress = {}
    
    -- Clear all infection effects
    SetPlayerStaminaSprintDepletionMultiplier(PlayerId(), 1.0)
    
    if Config.InfectionSystem.debugging.enabled then
        print("[INFECTION] All infections cleared - effects reset")
    end
end)

exports('GetCureProgress', function(bodyPart)
    return bodyPart and InfectionCureProgress[bodyPart] or InfectionCureProgress
end)

exports('CreateForceInfection', function(bodyPart, stage)
    if not Config.InfectionSystem.enabled then return false end
    
    -- Validate inputs
    if not bodyPart or not Config.BodyParts[bodyPart] then return false end
    if not stage or stage < 1 or stage > #Config.InfectionSystem.stages then return false end
    
    -- Create infection at specified stage
    PlayerInfections[bodyPart] = {
        stage = stage,
        startTime = GetGameTimer(),
        lastProgressCheck = GetGameTimer(),
        metadata = {
            causeDescription = "Developer forced infection",
            symptoms = {},
            treatments = {}
        }
    }
    
    -- Initialize cure progress
    InfectionCureProgress[bodyPart] = 0.0
    
    -- Add symptoms up to current stage
    for i = 1, stage do
        if Config.InfectionSystem.stages[i] and Config.InfectionSystem.stages[i].symptom then
            table.insert(PlayerInfections[bodyPart].metadata.symptoms, Config.InfectionSystem.stages[i].symptom)
        end
    end
    
    -- Show current stage symptom
    ShowInfectionSymptom(bodyPart, stage)
    
    -- Update server
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateInfectionData', PlayerInfections)
    
    if Config.InfectionSystem.debugging.enabled then
        print(string.format("[INFECTION] Force created infection on %s at stage %d", bodyPart, stage))
    end
    
    return true
end)

--=========================================================
-- NETWORK EVENTS
--=========================================================
RegisterNetEvent('QC-AdvancedMedic:client:SyncInfectionData')
AddEventHandler('QC-AdvancedMedic:client:SyncInfectionData', function(infectionData)
    PlayerInfections = infectionData or {}
end)

RegisterNetEvent('QC-AdvancedMedic:client:TreatInfection')
AddEventHandler('QC-AdvancedMedic:client:TreatInfection', function(bodyPart, treatmentItem)
    TreatInfection(bodyPart, treatmentItem)
end)

RegisterNetEvent('QC-AdvancedMedic:client:ApplyBandage')
AddEventHandler('QC-AdvancedMedic:client:ApplyBandage', function(bodyPart, bandageType)
    AddBandage(bodyPart, bandageType)
end)

-- Define global functions for cross-file access
function AddBandage(bodyPart, bandageType, data)
    local bandageConfig = Config.BandageTypes[bandageType]
    if not bandageConfig then return false end
    
    BandageTracker[bodyPart] = {
        bandageType = bandageType,
        appliedTime = GetGameTimer(),
        dirtyFactor = 0,
        lastUpdateTime = GetGameTimer(),
        appliedBy = data and data.appliedBy or GetPlayerServerId(PlayerId()),
        metadata = data and data.metadata or {}
    }
    return true
end

function RemoveBandage(bodyPart)
    BandageTracker[bodyPart] = nil
    return true
end

function CreateForceInfection(bodyPart, stage)
    if not Config.InfectionSystem.enabled then return false end
    if not bodyPart or not Config.BodyParts[bodyPart] then return false end
    if not stage or stage < 1 or stage > #Config.InfectionSystem.stages then return false end
    
    PlayerInfections[bodyPart] = {
        stage = stage,
        progressionTime = GetGameTimer(),
        immunityEnd = 0,
        symptoms = Config.InfectionSystem.stages[stage].symptom
    }
    
    InfectionCureProgress[bodyPart] = 0
    return true
end

RegisterNetEvent('QC-AdvancedMedic:client:LoadInfections')
AddEventHandler('QC-AdvancedMedic:client:LoadInfections', function(infectionData)
    if not infectionData then return end
    
    PlayerInfections = infectionData
    
    -- Initialize cure progress for loaded infections
    for bodyPart, infection in pairs(PlayerInfections) do
        if not InfectionCureProgress[bodyPart] then
            InfectionCureProgress[bodyPart] = 0.0
        end
    end
    
    if Config.InfectionSystem.debugging.enabled then
        local count = 0
        for _ in pairs(PlayerInfections) do count = count + 1 end
        print(string.format("[PERSISTENCE] Loaded %d infections from database", count))
    end
end)

RegisterNetEvent('QC-AdvancedMedic:client:UseCureItem')
AddEventHandler('QC-AdvancedMedic:client:UseCureItem', function(cureType)
    local ped = PlayerPedId()
    local cureConfig = Config.InfectionSystem.cureItems[cureType]
    
    if not cureConfig then
        lib.notify({
            title = "Treatment Error",
            description = "Unknown cure item",
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Check if player has any infections
    local hasInfection = false
    for bodyPart, infection in pairs(PlayerInfections) do
        hasInfection = true
        break
    end
    
    if not hasInfection then
        lib.notify({
            title = "No Infections",
            description = "You don't have any infections to treat",
            type = 'inform',
            duration = 5000
        })
        return
    end
    
    -- Start treatment animation/progress bar
    if lib.progressBar({
        duration = cureConfig.treatmentTime,
        label = string.format('Using %s...', cureConfig.label),
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
        -- Treatment completed - apply to most severe infection
        local mostSevereBodyPart = nil
        local highestStage = 0
        
        for bodyPart, infection in pairs(PlayerInfections) do
            if infection.stage > highestStage then
                highestStage = infection.stage
                mostSevereBodyPart = bodyPart
            end
        end
        
        if mostSevereBodyPart then
            TreatInfection(mostSevereBodyPart, cureType)
        end
    else
        -- Treatment cancelled
        lib.notify({
            title = "Treatment Cancelled",
            description = "Treatment was interrupted",
            type = 'error',
            duration = 3000
        })
    end
end)

