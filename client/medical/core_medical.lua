--=========================================================
-- QC-ADVANCED MEDIC - CORE MEDICAL SYSTEM
--=========================================================
-- Consolidated medical system following patterns
-- Merges: wound_system.lua + treatment_system.lua + wound_healing.lua
-- Version: 0.3.1 Refactored
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

--============================================
-- SECTION 1: STATE MANAGEMENT (Lines 1-150)
--============================================
-- Centralized medical state (eliminates scattered globals)
local MedicalState = {
    wounds = {},              -- Previously: PlayerWounds
    treatments = {},          -- Previously: ActiveTreatments
    healingTimers = {},       -- Previously: HealingTimers
    medicineEffects = {},     -- Previously: MedicineEffects
    injectionEffects = {},    -- Previously: InjectionEffects
    playerHealth = nil,       -- Previously: PlayerHealth
    bleedingLevel = 0,        -- Previously: BleedingLevel
    infectionData = {},       -- Previously: InfectionData
}

-- Limb effects tracking
local LimbEffects = {
    movementPenalty = 0.0,
    onMorphine = 0,
    wasOnMorphine = false,
    legCount = 0,
    armCount = 0,
    headCount = 0
}

-- Damage tracking
local LastDamageWeapon = nil
local LastDamageTime = 0
local ApplyingMedicalDamage = false
local LastWeaponDamageTime = {}
local DAMAGE_COOLDOWN = 500

-- Controlled state access (pattern)
local function GetMedicalState(key)
    if key then
        return MedicalState[key]
    end
    return MedicalState
end

-- Update state and sync to LocalPlayer.state for cross-file access
local function UpdateMedicalState(key, value, replicate)
    if not key then return end

    MedicalState[key] = value

    -- Optional: sync to LocalPlayer.state for server replication
    if replicate then
        LocalPlayer.state:set('medical_' .. key, value, true)
    end
end

-- Backwards compatibility globals (will be removed in future versions)
PlayerWounds = MedicalState.wounds
ActiveTreatments = MedicalState.treatments

--============================================
-- SECTION 2: UTILITY FUNCTIONS (Lines 151-350)
--============================================

-- Calculate body part health based on damage
local function CalculateBodyPartHealth(bodyPart, painLevel, bleedingLevel)
    local bodyPartConfig = Config.BodyParts[bodyPart]
    if not bodyPartConfig then return 100.0, 100.0, 100.0 end

    local maxHealth = bodyPartConfig.maxHealth
    local totalDamage = (painLevel or 0) + (bleedingLevel or 0)

    -- Scale damage: 30% health loss per 10 damage points (max 60% loss)
    local scalingFactor = 0.3
    local healthLoss = (totalDamage * scalingFactor * maxHealth) / 10
    local currentHealth = math.max(0, maxHealth - healthLoss)
    local healthPercentage = (currentHealth / maxHealth) * 100

    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        print(string.format("^2[HEALTH] %s: %.1f%% (Pain:%.1f Bleed:%.1f)^7",
            bodyPart, healthPercentage, painLevel or 0, bleedingLevel or 0))
    end

    return currentHealth, maxHealth, healthPercentage
end

-- Get body part health data for UI
function GetBodyPartHealthData()
    local healthData = {}

    -- Default all body parts to 100% health
    for bodyPart, config in pairs(Config.BodyParts) do
        healthData[bodyPart] = {
            current = config.maxHealth,
            max = config.maxHealth,
            percentage = 100.0
        }
    end

    -- Update with wound data if it exists
    for bodyPart, wound in pairs(MedicalState.wounds) do
        if not wound.isScar and wound.currentHealth then
            healthData[bodyPart] = {
                current = wound.currentHealth,
                max = wound.maxHealth or Config.BodyParts[bodyPart].maxHealth,
                percentage = wound.healthPercentage or 100.0
            }
        end
    end

    return healthData
end

-- Wound type detection for healing system
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

--============================================
-- SECTION 3: DAMAGE DETECTION (Lines 351-850)
--============================================

-- Enhanced weapon detection system
local function FindActualWeaponUsed()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local weaponFound = nil

    -- Check nearby peds (both players and NPCs) for actual combat actions
    local nearbyPeds = {}

    -- Add all players
    local players = GetActivePlayers()
    for _, playerId in ipairs(players) do
        if playerId ~= PlayerId() then
            local otherPed = GetPlayerPed(playerId)
            if DoesEntityExist(otherPed) then
                table.insert(nearbyPeds, otherPed)
            end
        end
    end

    -- Add nearby NPCs
    local handle, ped = FindFirstPed()
    local success
    repeat
        if DoesEntityExist(ped) and ped ~= playerPed and not IsPedAPlayer(ped) then
            local distance = #(playerCoords - GetEntityCoords(ped))
            if distance <= 10.0 then
                table.insert(nearbyPeds, ped)
            end
        end
        success, ped = FindNextPed(handle)
    until not success
    EndFindPed(handle)

    -- Check all nearby peds for combat actions
    for _, otherPed in ipairs(nearbyPeds) do
        if DoesEntityExist(otherPed) then
            local distance = #(playerCoords - GetEntityCoords(otherPed))

            -- Only check peds within reasonable combat range
            if distance <= 10.0 then
                local currentWeapon = GetCurrentPedWeapon(otherPed)
                local isShooting = IsPedShooting(otherPed)
                local isInMelee = IsPedInMeleeCombat(otherPed)

                -- Priority 1: If they're shooting with a weapon, use that weapon
                if isShooting and currentWeapon and currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 1 then
                    if Config.WeaponDamage[currentWeapon] then
                        weaponFound = currentWeapon
                        if Config.WoundSystem.debugging.enabled then
                            print(string.format("^2[WEAPON DETECT] Found shooter with weapon: %s^7", tostring(currentWeapon)))
                        end
                        break
                    end
                end

                -- Priority 2: If they're in melee combat, use unarmed or their melee weapon
                if isInMelee then
                    if currentWeapon == GetHashKey("WEAPON_UNARMED") or not currentWeapon or currentWeapon == 1 then
                        weaponFound = GetHashKey("WEAPON_UNARMED")
                    else
                        -- Check if current weapon is a melee weapon
                        if Config.WeaponDamage[currentWeapon] and
                           (Config.WeaponDamage[currentWeapon].ballisticType == "melee" or
                            string.find(Config.WeaponDamage[currentWeapon].data or "", "Knife") or
                            string.find(Config.WeaponDamage[currentWeapon].data or "", "Hatchet")) then
                            weaponFound = currentWeapon
                        else
                            weaponFound = GetHashKey("WEAPON_UNARMED")
                        end
                    end
                    break
                end
            end
        end
    end

    -- Check for animal attacks
    local animalAttackDetected = false
    for _, otherPed in ipairs(nearbyPeds) do
        if DoesEntityExist(otherPed) then
            local distance = #(playerCoords - GetEntityCoords(otherPed))
            if distance <= 3.0 then
                if not IsPedAPlayer(otherPed) then
                    local isHuman = IsPedHuman(otherPed)
                    local isAnimal = GetIsAnimal(otherPed)
                    local model = GetEntityModel(otherPed)

                    if not isHuman and isAnimal and IsPedInMeleeCombat(otherPed) then
                        local animalWeapon = GetHashKey("WEAPON_ANIMAL")

                        -- Animal model to weapon mapping
                        local animalWeaponMap = {
                            [-1392359921] = GetHashKey("WEAPON_WOLF"),
                            [GetHashKey("a_c_wolf")] = GetHashKey("WEAPON_WOLF"),
                            [GetHashKey("a_c_cougar")] = GetHashKey("WEAPON_COUGAR"),
                            [GetHashKey("a_c_bear_01")] = GetHashKey("WEAPON_BEAR"),
                            [GetHashKey("a_c_snake_01")] = GetHashKey("WEAPON_SNAKE"),
                            [GetHashKey("a_c_horse_01")] = GetHashKey("WEAPON_HORSE"),
                            -- Add more as needed
                        }

                        if animalWeaponMap[model] then
                            animalWeapon = animalWeaponMap[model]
                        end

                        if animalWeapon then
                            weaponFound = animalWeapon
                            animalAttackDetected = true
                            if Config.WoundSystem.debugging.enabled then
                                print(string.format("^1[ANIMAL] Detected %s attack^7", tostring(animalWeapon)))
                            end
                            break
                        end
                    end
                end
            end
        end
    end

    -- Check for ragdoll falls
    if not weaponFound and not animalAttackDetected then
        if IsPedRagdoll(playerPed) then
            weaponFound = GetHashKey("WEAPON_FALL")
            if Config.WoundSystem.debugging.enabled then
                print("^3[RAGDOLL FALL] Detected ragdoll state - assuming fall damage^7")
            end
        end
    end

    -- Fallback: Check damage flags
    if not weaponFound and not animalAttackDetected then
        for weaponHash, weaponData in pairs(Config.WeaponDamage) do
            if HasEntityBeenDamagedByWeapon(playerPed, weaponHash, 0) then
                weaponFound = weaponHash
                if Config.WoundSystem.debugging.enabled then
                    print(string.format("^3[FALLBACK] Using damage flag: %s^7", weaponData.data or "unknown"))
                end
                ClearEntityLastDamageEntity(playerPed)
                HasEntityBeenDamagedByWeapon(playerPed, weaponHash, 2)
                break
            end
        end
    end

    return weaponFound
end

-- Calculate damaged body part based on ped bones
local function CalculateDamagedBodyPart()
    local playerPed = PlayerPedId()
    local damagedBone = GetPedLastDamageBone(playerPed)

    -- Map bone to body part
    local bodyPart = "torso" -- Default

    -- Head bones
    if damagedBone == 21030 or damagedBone == 31086 then
        bodyPart = "head"
    -- Arm bones
    elseif damagedBone == 37119 or damagedBone == 40269 then
        bodyPart = "left_arm"
    elseif damagedBone == 28252 or damagedBone == 6442 then
        bodyPart = "right_arm"
    -- Leg bones  elseif damagedBone == 65478 or damagedBone == 55120 then
        bodyPart = "left_leg"
    elseif damagedBone == 45454 or damagedBone == 43312 then
        bodyPart = "right_leg"
    end

    return bodyPart
end

-- Process damage event and create wound
local function DetectPlayerDamage(eventData)
    if ApplyingMedicalDamage then return end

    local currentTime = GetGameTimer()
    if currentTime - LastDamageTime < DAMAGE_COOLDOWN then
        return
    end
    LastDamageTime = currentTime

    local playerPed = PlayerPedId()
    local victim = tonumber(eventData[1])

    if victim ~= playerPed then return end

    -- Find weapon used
    local weaponHash = FindActualWeaponUsed()
    if not weaponHash then return end

    -- Get weapon configuration
    local weaponData = Config.WeaponDamage[weaponHash]
    if not weaponData then
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^3[DAMAGE] Unknown weapon: %s^7", tostring(weaponHash)))
        end
        return
    end

    -- Calculate damaged body part
    local bodyPart = CalculateDamagedBodyPart()

    -- Calculate pain and bleeding levels based on weapon type
    local painLevel = weaponData.painLevel or 5
    local bleedingLevel = weaponData.bleedingLevel or 5

    -- Check if wound already exists
    local existingWound = MedicalState.wounds[bodyPart]

    if existingWound then
        -- Increase severity on repeat hits
        if existingWound.severity and existingWound.severity < 4 then
            existingWound.severity = existingWound.severity + 1
        end

        -- Increase bleeding and pain
        existingWound.bleedingLevel = math.min((existingWound.bleedingLevel or 0) + bleedingLevel, 10)
        existingWound.painLevel = math.min((existingWound.painLevel or 0) + painLevel, 10)

        -- Recalculate health
        local currentHealth, maxHealth, healthPercentage = CalculateBodyPartHealth(
            bodyPart, existingWound.painLevel, existingWound.bleedingLevel
        )
        existingWound.currentHealth = currentHealth
        existingWound.maxHealth = maxHealth
        existingWound.healthPercentage = healthPercentage
    else
        -- Create new wound
        CreateWound(bodyPart, painLevel, bleedingLevel, {
            weaponHash = weaponHash,
            weaponType = weaponData.data,
            timestamp = currentTime
        })
    end

    -- Sync to server
    PlayerWounds = MedicalState.wounds
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', MedicalState.wounds)

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[DAMAGE] %s hit by %s - Pain: %.1f, Bleeding: %.1f^7",
            bodyPart, weaponData.data or "unknown", painLevel, bleedingLevel))
    end
end

-- Register damage event listener
AddEventHandler("gameEventTriggered", function(event, eventData)
    if event == "CEventNetworkEntityDamage" then
        DetectPlayerDamage(eventData)
    end
end)

--============================================
-- SECTION 4: WOUND MANAGEMENT (Lines 801-1400)
--============================================

-- Create a new wound
local function CreateWound(bodyPart, painLevel, bleedingLevel, metadata)
    local currentHealth, maxHealth, healthPercentage = CalculateBodyPartHealth(bodyPart, painLevel, bleedingLevel)

    MedicalState.wounds[bodyPart] = {
        painLevel = painLevel or 0,
        bleedingLevel = bleedingLevel or 0,
        severity = 1,
        timestamp = GetGameTimer(),
        currentHealth = currentHealth,
        maxHealth = maxHealth,
        healthPercentage = healthPercentage,
        metadata = metadata or {},
        isScar = false
    }

    -- Update global for backwards compatibility
    PlayerWounds = MedicalState.wounds

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[WOUND CREATED] %s: Pain=%.1f, Bleeding=%.1f^7",
            bodyPart, painLevel, bleedingLevel))
    end

    return MedicalState.wounds[bodyPart]
end

-- Update an existing wound
local function UpdateWound(bodyPart, changes)
    local wound = MedicalState.wounds[bodyPart]
    if not wound then return false end

    -- Store original values for rollback
    local originalPain = wound.painLevel
    local originalBleeding = wound.bleedingLevel

    -- Apply changes
    for key, value in pairs(changes) do
        wound[key] = value
    end

    -- Recalculate health
    if changes.painLevel or changes.bleedingLevel then
        local currentHealth, maxHealth, healthPercentage = CalculateBodyPartHealth(
            bodyPart, wound.painLevel, wound.bleedingLevel
        )
        wound.currentHealth = currentHealth
        wound.maxHealth = maxHealth
        wound.healthPercentage = healthPercentage
    end

    -- Server-authoritative update with callback
    QCMedic.Callbacks.ServerCallback('UpdateWoundData', MedicalState.wounds, function(success, errorCode)
        if not success then
            -- Rollback changes on failure
            wound.painLevel = originalPain
            wound.bleedingLevel = originalBleeding

            lib.notify({
                title = locale('cl_menu_treatment_error'),
                description = locale('cl_desc_server_sync_failed'),
                type = 'error',
                duration = 5000
            })

            if Config.WoundSystem.debugging.enabled then
                print(string.format("^1[UPDATE WOUND] Failed: %s^7", errorCode or "UNKNOWN"))
            end
            return
        end
    end)

    -- Update global for backwards compatibility
    PlayerWounds = MedicalState.wounds

    return true
end

-- Remove a wound
local function RemoveWound(bodyPart)
    if not MedicalState.wounds[bodyPart] then return false end

    MedicalState.wounds[bodyPart] = nil

    -- Update global for backwards compatibility
    PlayerWounds = MedicalState.wounds

    -- Stop any active healing
    if MedicalState.healingTimers[bodyPart] then
        MedicalState.healingTimers[bodyPart] = nil
    end

    -- Remove any treatments
    if MedicalState.treatments[bodyPart] then
        MedicalState.treatments[bodyPart] = nil
        ActiveTreatments = MedicalState.treatments
    end

    -- Sync to server
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', MedicalState.wounds)

    return true
end

--============================================
-- SECTION 5: TREATMENT APPLICATION (Lines 1401-2200)
--============================================

-- Apply bandage treatment
function ApplyBandage(bodyPart, bandageType, appliedBy)
    local bandageConfig = Config.BandageTypes[bandageType]
    if not bandageConfig then
        print("[ERROR] Unknown bandage type: " .. tostring(bandageType))
        return false
    end

    local bodyPartConfig = Config.BodyParts[bodyPart]
    if not bodyPartConfig then
        print("[ERROR] Unknown body part: " .. tostring(bodyPart))
        return false
    end

    -- Get current wound for this body part
    local wound = MedicalState.wounds[bodyPart]

    if not wound then
        lib.notify({
            title = locale('cl_menu_treatment'),
            description = string.format(locale('cl_desc_fmt_no_injury_detected'), bodyPartConfig.label),
            type = 'error',
            duration = 5000
        })
        return false
    end

    -- Check if wound is bleeding
    if not wound.bleedingLevel or wound.bleedingLevel <= 0 then
        lib.notify({
            title = locale('cl_menu_treatment'),
            description = string.format(locale('cl_desc_fmt_no_bleeding_detected'), bodyPartConfig.label),
            type = 'error',
            duration = 5000
        })
        return false
    end

    -- Check if bandage already applied
    if MedicalState.treatments[bodyPart] and MedicalState.treatments[bodyPart].treatmentType == "bandage" then
        lib.notify({
            title = locale('cl_menu_treatment_error'),
            description = string.format(locale('cl_desc_fmt_bandage_already_applied'), bodyPartConfig.label),
            type = 'error',
            duration = 5000
        })
        return false
    end

    -- ONE-TIME HEAL: Apply immediate health restoration
    if bandageConfig.oneTimeHeal and bandageConfig.oneTimeHeal > 0 then
        local ped = PlayerPedId()
        local currentHealth = GetEntityHealth(ped)
        local newHealth = math.min(currentHealth + bandageConfig.oneTimeHeal, Config.MaxHealth)
        SetEntityHealth(ped, newHealth)

        if Config.WoundSystem.debugging.enabled then
            print(string.format("^2[BANDAGE] %s: +%d heal^7",
                bodyPartConfig.label, bandageConfig.oneTimeHeal))
        end
    end

    -- Store original wound levels for rollback
    local originalPain = wound.painLevel
    local originalBleeding = wound.bleedingLevel

    -- BLEEDING REDUCTION (immediate effect)
    local bleedingReduction = 0
    if wound.bleedingLevel > 0 and bandageConfig.bleedingReduction then
        bleedingReduction = bandageConfig.bleedingReduction
        wound.bleedingLevel = math.max(wound.bleedingLevel - bleedingReduction, 1)
    end

    -- PAIN REDUCTION (proportional to bleeding reduction)
    local painReduction = 0
    if bleedingReduction > 0 and wound.painLevel > 0 then
        painReduction = bleedingReduction
        wound.painLevel = math.max(wound.painLevel - painReduction, 2)
    end

    -- Update wound data on server (SERVER-AUTHORITATIVE WITH CALLBACK)
    QCMedic.Callbacks.ServerCallback('UpdateWoundData', MedicalState.wounds, function(success, errorCode)
        if not success then
            -- Rollback wound changes on failure
            wound.bleedingLevel = originalBleeding
            wound.painLevel = originalPain

            lib.notify({
                title = locale('cl_menu_treatment_error'),
                description = locale('cl_desc_server_sync_failed'),
                type = 'error',
                duration = 5000
            })

            if Config.WoundSystem.debugging.enabled then
                print(string.format("^1[BANDAGE CALLBACK] Failed: %s^7", errorCode or "UNKNOWN"))
            end
            return
        end

        if Config.WoundSystem.debugging.enabled then
            print(string.format("^2[BANDAGE CALLBACK] Success^7"))
        end
    end)

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^3[BANDAGE] Pain:%.1f→%.1f Bleed:%.1f→%.1f^7",
            originalPain or 0, wound.painLevel or 0, originalBleeding or 0, wound.bleedingLevel or 0))
    end

    -- Track bandage treatment
    local currentTime = GetGameTimer()
    local expirationTime = currentTime + (bandageConfig.decayRate * 60 * 1000)

    MedicalState.treatments[bodyPart] = {
        treatmentType = "bandage",
        itemType = bandageType,
        appliedTime = currentTime,
        expirationTime = expirationTime,
        effectiveness = bandageConfig.effectiveness or 100,
        appliedBy = appliedBy,
        isActive = true,
        originalPain = originalPain,
        originalBleeding = originalBleeding,
        painReduction = painReduction,
        bleedingReduction = bleedingReduction
    }

    -- Update global for backwards compatibility
    ActiveTreatments = MedicalState.treatments
    PlayerWounds = MedicalState.wounds

    -- Notify player
    lib.notify({
        title = locale('cl_menu_treatment'),
        description = string.format(locale('cl_desc_fmt_bandage_applied'), bodyPartConfig.label),
        type = 'success',
        duration = 5000
    })

    return true
end

-- Apply tourniquet treatment (global application, circuit-damage pattern)
function ApplyTourniquet(tourniquetType, appliedBy)
    local tourniquetConfig = Config.TourniquetTypes[tourniquetType]

    -- Validation 1: Config exists
    if not tourniquetConfig then
        print("[ERROR] Unknown tourniquet type: " .. tostring(tourniquetType))
        return false
    end

    -- Validation 2: Check if ANY wound has bleeding
    local hasBleedingWounds = false
    for _, wound in pairs(MedicalState.wounds) do
        if wound.bleedingLevel and wound.bleedingLevel > 0 then
            hasBleedingWounds = true
            break
        end
    end

    if not hasBleedingWounds then
        lib.notify({
            title = locale('cl_menu_treatment'),
            description = locale('cl_desc_no_bleeding_wounds'),
            type = 'error',
            duration = 5000
        })
        return false
    end

    -- Validation 3: Check if tourniquet already active globally
    if LocalPlayer.state.tourniquet and LocalPlayer.state.tourniquet > GetGameTimer() then
        lib.notify({
            title = locale('cl_menu_treatment_error'),
            description = locale('cl_desc_tourniquet_already_active'),
            type = 'error',
            duration = 5000
        })
        return false
    end

    -- Apply tourniquet globally - store single timestamp (circuit-damage pattern)
    local currentTime = GetGameTimer()
    local duration = (tourniquetConfig.maxDuration or 30) * 60 * 1000 -- Convert minutes to ms
    local expirationTime = currentTime + duration

    -- Set global tourniquet timestamp
    LocalPlayer.state:set('tourniquet', expirationTime, false)

    -- STOP bleeding on ALL wounds immediately
    for bodyPart, wound in pairs(MedicalState.wounds) do
        if wound.bleedingLevel and wound.bleedingLevel > 0 then
            wound.isTourniqueted = true  -- Flag for NUI display
        end
    end

    -- Notify player
    lib.notify({
        title = locale('cl_menu_tourniquet_applied'),
        description = string.format(
            locale('cl_desc_fmt_tourniquet_global'),
            tourniquetConfig.label,
            math.floor(tourniquetConfig.maxDuration)
        ),
        type = 'success',
        duration = 5000
    })

    -- Server callback to log event
    if appliedBy then
        TriggerServerEvent('QC-AdvancedMedic:server:LogTourniquetApplication', {
            tourniquetType = tourniquetType,
            appliedBy = appliedBy,
            expirationTime = expirationTime
        })
    end

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[TOURNIQUET] Applied globally, expires in %.1f minutes^7",
            tourniquetConfig.maxDuration))
    end

    return true
end

-- Remove tourniquet
local function RemoveTourniquet(bodyPart, reason)
    if not MedicalState.treatments[bodyPart] or MedicalState.treatments[bodyPart].treatmentType ~= "tourniquet" then
        return false
    end

    -- Remove from state
    MedicalState.treatments[bodyPart] = nil
    ActiveTreatments = MedicalState.treatments

    -- Remove from LocalPlayer.state
    local tourniquets = LocalPlayer.state.tourniquets or {}
    tourniquets[bodyPart] = nil
    LocalPlayer.state:set('tourniquets', tourniquets, false)

    -- Notify player
    local bodyPartConfig = Config.BodyParts[bodyPart]
    lib.notify({
        title = locale('cl_menu_treatment'),
        description = string.format(locale('cl_desc_fmt_tourniquet_removed'),
            bodyPartConfig and bodyPartConfig.label or bodyPart, reason or "expired"),
        type = 'inform',
        duration = 5000
    })

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^3[TOURNIQUET] Removed from %s: %s^7", bodyPart, reason or "expired"))
    end

    return true
end

-- Administer medicine
function AdministreMedicine(medicineType, appliedBy)
    local medicineConfig = Config.MedicineTypes[medicineType]
    if not medicineConfig then
        print("[ERROR] Unknown medicine type: " .. tostring(medicineType))
        return false
    end

    -- Apply medicine effects
    -- (Implementation to be completed based on existing medicine system)

    lib.notify({
        title = locale('cl_menu_treatment'),
        description = string.format(locale('cl_desc_fmt_medicine_taken'), medicineConfig.label or medicineType),
        type = 'success',
        duration = 5000
    })

    return true
end

-- Give injection
function GiveInjection(injectionType, appliedBy)
    local injectionConfig = Config.InjectionTypes[injectionType]
    if not injectionConfig then
        print("[ERROR] Unknown injection type: " .. tostring(injectionType))
        return false
    end

    -- Apply injection effects
    -- (Implementation to be completed based on existing injection system)

    lib.notify({
        title = locale('cl_menu_treatment'),
        description = string.format(locale('cl_desc_fmt_injection_given'), injectionConfig.label or injectionType),
        type = 'success',
        duration = 5000
    })

    return true
end

-- Remove treatment
local function RemoveTreatment(bodyPart)
    if not MedicalState.treatments[bodyPart] then return false end

    local treatment = MedicalState.treatments[bodyPart]

    -- Special handling for tourniquets
    if treatment.treatmentType == "tourniquet" then
        return RemoveTourniquet(bodyPart, "manual removal")
    end

    MedicalState.treatments[bodyPart] = nil
    ActiveTreatments = MedicalState.treatments

    return true
end

--============================================
-- SECTION 6: HEALING & PROGRESSION (Lines 2201-2600)
--============================================

-- Start wound healing process
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

    MedicalState.healingTimers[bodyPart] = {
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
        description = string.format(locale('cl_desc_fmt_wound_beginning_heal'),
            Config.BodyParts[bodyPart] and Config.BodyParts[bodyPart].label:lower() or bodyPart),
        type = Config.WoundHealing.notifications.healingStarted.type,
        duration = Config.WoundHealing.notifications.healingStarted.duration
    })
end

-- Stop wound healing
local function StopHealing(bodyPart, reason)
    if not MedicalState.healingTimers[bodyPart] then return end

    MedicalState.healingTimers[bodyPart] = nil

    if Config.WoundHealing.debugging.enabled then
        print(string.format("^1[HEALING] Stopped healing %s - %s^7", bodyPart, reason))
    end

    -- Notify player
    lib.notify({
        title = Config.WoundHealing.notifications.healingInterrupted.title,
        description = string.format(locale('cl_desc_fmt_wound_healing_interrupted'),
            Config.BodyParts[bodyPart] and Config.BodyParts[bodyPart].label:lower() or bodyPart, reason),
        type = Config.WoundHealing.notifications.healingInterrupted.type,
        duration = Config.WoundHealing.notifications.healingInterrupted.duration
    })
end

-- Complete wound healing (convert to scar)
local function CompleteHealing(bodyPart, wound)
    if not MedicalState.healingTimers[bodyPart] then return end

    local healing = MedicalState.healingTimers[bodyPart]

    -- Convert wound to scar
    wound.isScar = true
    wound.scarTime = GetGameTimer()
    wound.scarType = healing.scarType
    wound.bleedingLevel = 0
    wound.painLevel = 0
    wound.healedDescription = healing.description

    -- Remove healing timer
    MedicalState.healingTimers[bodyPart] = nil

    if Config.WoundHealing.debugging.enabled then
        print(string.format("^2[HEALING] Completed healing %s to %s^7", bodyPart, healing.scarType))
    end

    -- Notify player
    lib.notify({
        title = Config.WoundHealing.notifications.healingComplete.title,
        description = string.format(locale('cl_desc_fmt_wound_healed_scar'),
            Config.BodyParts[bodyPart] and Config.BodyParts[bodyPart].label:lower() or bodyPart),
        type = Config.WoundHealing.notifications.healingComplete.type,
        duration = Config.WoundHealing.notifications.healingComplete.duration
    })

    -- Update server with scar data
    PlayerWounds = MedicalState.wounds
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', MedicalState.wounds)
end

-- Process wound healing (called periodically)
function ProcessWoundHealing()
    if not Config.WoundHealing.enabled then return end

    local currentTime = GetGameTimer()

    for bodyPart, wound in pairs(MedicalState.wounds) do
        if wound.isScar then goto continue end

        local treatment = MedicalState.treatments[bodyPart]
        local hasBandage = treatment and treatment.treatmentType == "bandage" and treatment.isActive
        local isBleedingMinimal = wound.bleedingLevel == 1

        -- Check if healing conditions are met
        local canHeal = hasBandage and isBleedingMinimal

        if Config.WoundHealing.debugging.showRequirementChecks then
            print(string.format("^6[HEALING] %s: bandaged=%s, bleeding=%.1f, canHeal=%s^7",
                bodyPart, tostring(hasBandage), wound.bleedingLevel or 0, tostring(canHeal)))
        end

        local isCurrentlyHealing = MedicalState.healingTimers[bodyPart] ~= nil

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
            local healing = MedicalState.healingTimers[bodyPart]
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
-- MOVEMENT & LIMB EFFECTS
--=========================================================

-- Process movement penalties from leg injuries
local function ProcessMovementEffects()
    local ped = PlayerPedId()
    local hasLegInjury = false
    local maxSeverity = 0

    -- Check for leg injuries that cause limping (severity-based)
    for bodyPart, wound in pairs(MedicalState.wounds) do
        local bodyPartConfig = Config.BodyParts[bodyPart]
        if bodyPartConfig and bodyPartConfig.limp and not wound.isScar then
            hasLegInjury = true
            -- Use severity level (1-4) for granular movement penalties
            if wound.severity and wound.severity > maxSeverity then
                maxSeverity = wound.severity
            end
        end
    end

    -- Apply movement penalties based on severity
    local onMorphine = MedicalState.medicineEffects and MedicalState.medicineEffects.morphine_effect and MedicalState.medicineEffects.morphine_effect > GetGameTimer()

    if hasLegInjury and not onMorphine then
        -- Severity-based movement rate: 1=98%, 2=96%, 3=94%, 4=92%
        local movementRates = { 0.98, 0.96, 0.94, 0.92 }
        local movementRate = movementRates[maxSeverity] or 0.92
        SetPedMoveRateOverride(ped, math.max(movementRate, 0.3)) -- Minimum 30% speed
    else
        SetPedMoveRateOverride(ped, 1.0)
    end
end

--=========================================================
-- BACKGROUND THREADS
--=========================================================

-- Bleeding damage loop (applies damage from untreated wounds every 30 seconds)
CreateThread(function()
    -- Wait for player to be fully loaded
    repeat Wait(1000) until LocalPlayer.state.isLoggedIn
    Wait(5000) -- Additional delay to ensure sync

    if Config.WoundSystem.debugging.enabled then
        print("^2[CORE MEDICAL] Bleeding damage loop started (30s intervals)^7")
    end

    while true do
        Wait(30000) -- 30 seconds

        -- Check if player is logged in and alive
        if not LocalPlayer.state.isLoggedIn then goto continue_bleeding_loop end

        local playerData = RSGCore.Functions.GetPlayerData()
        if not playerData or playerData.metadata.isdead then goto continue_bleeding_loop end

        local totalBleedingDamage = 0
        local bleedingWounds = {}

        -- Early exit if no wounds
        if not next(MedicalState.wounds) then goto continue_bleeding_loop end

        -- Global tourniquet check (circuit-damage pattern)
        -- If tourniquet is active, it COMPLETELY HALTS all bleeding - no damage, no progression
        local tourniquetActive = LocalPlayer.state.tourniquet and LocalPlayer.state.tourniquet > GetGameTimer()
        if tourniquetActive then
            goto continue_bleeding_loop
        end

        -- Calculate bleeding damage from untreated wounds
        for bodyPart, wound in pairs(MedicalState.wounds) do
            if not wound.isScar and wound.bleedingLevel and tonumber(wound.bleedingLevel) > 0 then
                local hasBandage = false

                -- Check for active bandage
                if MedicalState.treatments[bodyPart] and
                   MedicalState.treatments[bodyPart].treatmentType == "bandage" and
                   MedicalState.treatments[bodyPart].isActive then
                    hasBandage = true
                end

                -- Apply bleeding damage if not protected by bandage
                if not hasBandage then
                    local injuryState = Config.InjuryStates[wound.bleedingLevel]
                    if injuryState and injuryState.bleedingDamagePerTick then
                        totalBleedingDamage = totalBleedingDamage + injuryState.bleedingDamagePerTick
                        table.insert(bleedingWounds, {
                            bodyPart = bodyPart,
                            level = wound.bleedingLevel,
                            damage = injuryState.bleedingDamagePerTick
                        })
                    end
                end
            end
        end

        -- Apply total bleeding damage
        if totalBleedingDamage > 0 then
            local ped = PlayerPedId()
            PlayPain(ped, 9, 1, true, true)
            ApplyDamageToPed(ped, 10, false) -- Scaled damage to prevent instant death

            -- Notification
            if #bleedingWounds > 1 then
                lib.notify({
                    title = locale('cl_menu_medical_warning'),
                    description = string.format("Bleeding from %d wounds - you need medical treatment!", #bleedingWounds),
                    type = 'error',
                    duration = 7000
                })
            else
                local wound = bleedingWounds[1]
                lib.notify({
                    title = locale('cl_menu_medical_warning'),
                    description = string.format("%s is bleeding - apply bandage!", exports['QC-AdvancedMedic']:GetBodyPartLabel(wound.bodyPart)),
                    type = 'error',
                    duration = 7000
                })
            end
        end

        ::continue_bleeding_loop::
    end
end)

-- Tourniquet expiration handler (global tourniquet pattern)
CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.isLoggedIn

    while LocalPlayer.state.loggedIn do
        Wait(5000) -- Check every 5 seconds

        local currentTime = GetGameTimer()
        local tourniquetExpiry = LocalPlayer.state.tourniquet

        -- Check if tourniquet expired
        if tourniquetExpiry and tourniquetExpiry <= currentTime then
            -- Clear expired tourniquet
            LocalPlayer.state:set('tourniquet', nil, false)

            -- Remove isTourniqueted flags from all wounds
            for bodyPart, wound in pairs(MedicalState.wounds) do
                if wound.isTourniqueted then
                    wound.isTourniqueted = false
                end
            end

            lib.notify({
                title = locale('cl_menu_tourniquet_expired'),
                description = locale('cl_desc_tourniquet_wore_off'),
                type = 'warning',
                duration = 5000
            })

            if Config.WoundSystem.debugging.enabled then
                print("^3[TOURNIQUET] Tourniquet expired - bleeding may resume^7")
            end
        end
    end
end)

-- Movement-based bleeding acceleration (wounds worsen when moving)
CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.isLoggedIn

    local prevPos = GetEntityCoords(PlayerPedId())

    while LocalPlayer.state.loggedIn do
        Wait(3000) -- Check every 3 seconds

        -- Calculate total bleeding
        local totalBleeding = 0
        for _, wound in pairs(MedicalState.wounds) do
            if not wound.isScar and wound.bleedingLevel then
                totalBleeding = totalBleeding + wound.bleedingLevel
            end
        end

        -- Only accelerate if significant bleeding and not in vehicle
        if totalBleeding > 2 and not IsPedInAnyVehicle(PlayerPedId()) then
            local currPos = GetEntityCoords(PlayerPedId())
            local distance = #(vector2(prevPos.x, prevPos.y) - vector2(currPos.x, currPos.y))

            -- Player has moved more than 1 meter
            if distance > 1.0 then
                -- Accelerate wound progression
                for bodyPart, wound in pairs(MedicalState.wounds) do
                    if not wound.isScar and wound.bleedingLevel and wound.bleedingLevel > 0 then
                        -- Small chance to increase bleeding level
                        if math.random() < 0.05 then -- 5% chance per check
                            wound.bleedingLevel = math.min(wound.bleedingLevel + 0.5, 10)

                            if Config.WoundSystem.debugging.enabled then
                                print(string.format("^1[MOVEMENT BLEEDING] %s bleeding worsened (%.1f)^7",
                                    bodyPart, wound.bleedingLevel))
                            end
                        end
                    end
                end

                -- Show warning periodically
                if math.random() < 0.1 then -- 10% chance
                    lib.notify({
                        title = locale('cl_menu_medical_warning'),
                        description = "Moving with severe bleeding is making your wounds worse!",
                        type = 'error',
                        duration = 5000
                    })
                end
            end

            prevPos = currPos
        else
            prevPos = GetEntityCoords(PlayerPedId())
        end
    end
end)

-- Wound progression loop (movement effects + scar conversion)
CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.isLoggedIn

    while true do
        -- Use shortest interval from config
        local minInterval = math.min(
            (Config.WoundProgression.bandageHealingInterval or 1) * 60000,
            (Config.WoundProgression.bleedingProgressionInterval or 2) * 60000,
            (Config.WoundProgression.painProgressionInterval or 3) * 60000
        )

        Wait(minInterval)

        if not IsEntityDead(PlayerPedId()) then
            ProcessMovementEffects()
            -- Note: CheckAndConvertToScars is part of ProcessHealing in healing section
        end
    end
end)

--============================================
-- SECTION 7: EXPORTS (Lines 2601-2800)
--============================================
-- Single export point (pattern)

MEDICAL = {
    -- State access
    GetState = GetMedicalState,
    GetBodyPartHealthData = GetBodyPartHealthData,

    -- Wound operations
    CreateWound = CreateWound,
    UpdateWound = UpdateWound,
    RemoveWound = RemoveWound,

    -- Treatment operations
    ApplyBandage = ApplyBandage,
    ApplyTourniquet = ApplyTourniquet,
    AdministreMedicine = AdministreMedicine,
    GiveInjection = GiveInjection,
    RemoveTreatment = RemoveTreatment,
    RemoveTourniquet = RemoveTourniquet,

    -- Healing operations
    ProcessHealing = ProcessWoundHealing,
    StartHealing = StartHealing,
    StopHealing = StopHealing,
    CompleteHealing = CompleteHealing,
}

-- Auto-export all methods (pattern)
for key, value in pairs(MEDICAL) do
    if type(value) == "function" then
        exports(key, value)
    end
end

-- Individual function exports for backwards compatibility
ProcessWoundHealing = ProcessWoundHealing

if Config.WoundSystem.debugging.enabled then
    print("^2[CORE MEDICAL] System initialized - State consolidated^7")
end
