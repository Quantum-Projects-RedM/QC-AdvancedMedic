--=========================================================
-- QC-ADVANCED MEDIC - WOUND HEALING SYSTEM
--=========================================================
-- This file handles wound healing to scars when properly cared for
-- Requirements: bandaged + bleeding level 1 + maintained for full duration
-- If conditions break, healing timer resets
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- Healing tracking data
local HealingTimers = {} -- Tracks active healing processes

--=========================================================
-- HEALING DATA STRUCTURE
--=========================================================
-- HealingTimers[bodyPart] = {
--     woundType = "shot_through",
--     startTime = GetGameTimer(),
--     healTime = 15,  -- minutes from config
--     lastCheck = GetGameTimer(),
--     scarType = "entry_exit_scar"
-- }

--=========================================================
-- WOUND TYPE DETECTION
--=========================================================
local function GetWoundType(wound)
    if not wound or not wound.metadata then
        return "default"
    end
    
    -- Check bullet status first
    if wound.metadata.bulletStatus then
        if wound.metadata.bulletStatus == "through" then
            return "shot_through"
        elseif wound.metadata.bulletStatus == "stuck" then
            -- If bullet was removed surgically, it becomes post_surgery
            if wound.metadata.surgicallyRemoved then
                return "post_surgery"
            else
                -- Still has bullet lodged - cannot heal until removed
                return nil
            end
        elseif wound.metadata.bulletStatus == "fragmented" then
            return "fragmented"
        end
    end
    
    -- Check weapon type
    if wound.metadata.weaponType then
        local weaponType = wound.metadata.weaponType:lower()
        if weaponType:find("knife") or weaponType:find("blade") or weaponType:find("machete") then
            return "cutting"
        elseif weaponType:find("explosive") or weaponType:find("dynamite") or weaponType:find("fire") then
            return "explosive"
        elseif weaponType:find("animal") or weaponType:find("horse") or weaponType:find("deer") then
            return "crushing"
        end
    end
    
    return "default"
end

--=========================================================
-- HEALING PROCESS MANAGEMENT
--=========================================================
local function StartHealing(bodyPart, wound)
    if not Config.WoundHealing.enabled then return end
    
    local woundType = GetWoundType(wound)
    if not woundType then
        if Config.WoundHealing.debugging.enabled then
            print(string.format("^3[HEALING] Cannot heal %s - lodged bullet must be removed first^7", bodyPart))
        end
        return
    end
    
    local healingConfig = Config.WoundHealing.healingTimes[woundType]
    if not healingConfig then
        healingConfig = Config.WoundHealing.healingTimes["default"]
    end
    
    HealingTimers[bodyPart] = {
        woundType = woundType,
        startTime = GetGameTimer(),
        healTime = healingConfig.healTime,
        lastCheck = GetGameTimer(), 
        scarType = healingConfig.scarType,
        description = healingConfig.description
    }
    
    if Config.WoundHealing.debugging.enabled then
        print(string.format("^2[HEALING] Started healing %s (%s) - %d minutes required^7", 
            bodyPart, woundType, healingConfig.healTime))
    end
    
    -- Notify player
    lib.notify({
        title = Config.WoundHealing.notifications.healingStarted.title,
        description = string.format("Your %s wound is beginning to heal - keep it bandaged and bleeding at minimum", 
            Config.BodyParts[bodyPart] and Config.BodyParts[bodyPart].label:lower() or bodyPart),
        type = Config.WoundHealing.notifications.healingStarted.type,
        duration = Config.WoundHealing.notifications.healingStarted.duration
    })
end

local function StopHealing(bodyPart, reason)
    if not HealingTimers[bodyPart] then return end
    
    local healing = HealingTimers[bodyPart]
    HealingTimers[bodyPart] = nil
    
    if Config.WoundHealing.debugging.enabled then
        print(string.format("^1[HEALING] Stopped healing %s - %s^7", bodyPart, reason))
    end
    
    -- Notify player
    lib.notify({
        title = Config.WoundHealing.notifications.healingInterrupted.title,
        description = string.format("Your %s wound healing was interrupted - %s", 
            Config.BodyParts[bodyPart] and Config.BodyParts[bodyPart].label:lower() or bodyPart, reason),
        type = Config.WoundHealing.notifications.healingInterrupted.type,
        duration = Config.WoundHealing.notifications.healingInterrupted.duration
    })
end

local function CompleteHealing(bodyPart, wound)
    if not HealingTimers[bodyPart] then return end
    
    local healing = HealingTimers[bodyPart]
    
    -- Convert wound to scar
    wound.isScar = true
    wound.scarTime = GetGameTimer()
    wound.scarType = healing.scarType
    wound.bleedingLevel = 0
    wound.painLevel = 0
    wound.healedDescription = healing.description
    
    -- Remove healing timer
    HealingTimers[bodyPart] = nil
    
    if Config.WoundHealing.debugging.enabled then
        print(string.format("^2[HEALING] Completed healing %s to %s^7", bodyPart, healing.scarType))
    end
    
    -- Notify player
    lib.notify({
        title = Config.WoundHealing.notifications.healingComplete.title,
        description = string.format("Your %s wound has healed into a scar and stopped bleeding completely", 
            Config.BodyParts[bodyPart] and Config.BodyParts[bodyPart].label:lower() or bodyPart),
        type = Config.WoundHealing.notifications.healingComplete.type,
        duration = Config.WoundHealing.notifications.healingComplete.duration
    })
    
    -- Update server with scar data
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', PlayerWounds)
end

--=========================================================
-- HEALING PROCESS CHECKER
--=========================================================
function ProcessWoundHealing()
    if not Config.WoundHealing.enabled then return end
    
    local currentTime = GetGameTimer()
    local activeTreatments = ActiveTreatments or {}
    
    for bodyPart, wound in pairs(PlayerWounds or {}) do
        if wound.isScar then goto continue end
        
        local treatment = activeTreatments[bodyPart]
        local hasBandage = treatment and treatment.treatmentType == "bandage" and treatment.isActive
        local isBleedingMinimal = wound.bleedingLevel == 1
        
        -- Check if healing conditions are met
        local canHeal = hasBandage and isBleedingMinimal
        
        if Config.WoundHealing.debugging.showRequirementChecks then
            print(string.format("^6[HEALING] %s: bandaged=%s, bleeding=%.1f, canHeal=%s^7", 
                bodyPart, tostring(hasBandage), wound.bleedingLevel or 0, tostring(canHeal)))
        end
        
        local isCurrentlyHealing = HealingTimers[bodyPart] ~= nil
        
        if canHeal and not isCurrentlyHealing then
            -- Start healing process
            StartHealing(bodyPart, wound)
            
        elseif not canHeal and isCurrentlyHealing then
            -- Stop healing - conditions no longer met
            local reason = ""
            if not hasBandage then
                reason = "bandage removed or expired"
            elseif not isBleedingMinimal then
                reason = string.format("bleeding increased to level %d", wound.bleedingLevel)
            end
            StopHealing(bodyPart, reason)
            
        elseif canHeal and isCurrentlyHealing then
            -- Continue healing - check if complete
            local healing = HealingTimers[bodyPart]
            local elapsedMinutes = (currentTime - healing.startTime) / 1000 / 60
            
            if Config.WoundHealing.debugging.showHealingProgress then
                print(string.format("^2[HEALING] %s: %.1f/%.1f minutes (%.1f%%)^7", 
                    bodyPart, elapsedMinutes, healing.healTime, (elapsedMinutes / healing.healTime) * 100))
            end
            
            if elapsedMinutes >= healing.healTime then
                CompleteHealing(bodyPart, wound)
            end
        end
        
        ::continue::
    end
end

--=========================================================
-- EXPORTS
--=========================================================
exports('ProcessWoundHealing', ProcessWoundHealing)
exports('GetHealingTimers', function() return HealingTimers end)
exports('ForceStopHealing', function(bodyPart, reason) 
    StopHealing(bodyPart, reason or "forced stop") 
end)

-- Make function globally accessible
ProcessWoundHealing = ProcessWoundHealing