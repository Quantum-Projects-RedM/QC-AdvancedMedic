--=========================================================
-- QC-ADVANCED MEDIC - CORE MEDICAL SYSTEM (Simplified)
--=========================================================
-- Global bleeding + bandage change cycle system
-- No per-body-part tracking - everything is global
-- Version: 0.4.0 Simplified
--=========================================================

QCMed = QCMed or {}

local RSGCore = exports['rsg-core']:GetCoreObject()

--============================================
-- SECTION 1: STATE MANAGEMENT
--============================================
local MedicalState = {
    bleedingLevel = 0,            -- Global 0-10 bleeding (accumulated from weapon hits)
    bandageChangesNeeded = 0,     -- Total bandage changes to fully heal (from weapon config, stacks)
    bandageChangesApplied = 0,    -- How many bandage changes completed
    activeBandage = nil,          -- { type, appliedTime, expirationTime, config }
    lastWoundSource = nil,        -- Last weapon data string (for descriptions)
    lastHitBone = 14411,          -- Last bone hit by damage (default: SKEL_Spine3/stomach)
    woundTimestamp = 0,           -- When first wound occurred
    medicineEffects = {},         -- Active medicine effect expirations
    injectionEffects = {},        -- Active injection effect expirations
}

-- Damage tracking
local LastDamageTime = 0
local ApplyingMedicalDamage = false
local DAMAGE_COOLDOWN = 500
local bandageTickThread = nil     -- Reference to active bandage tick thread

-- Controlled state access
local function GetMedicalState(key)
    if key then
        return MedicalState[key]
    end
    return MedicalState
end

-- Check if player is wounded (has bleeding or needs bandage changes)
local function IsWounded()
    return MedicalState.bleedingLevel > 0 or MedicalState.bandageChangesNeeded > 0
end

-- Check if fully healed
local function IsFullyHealed()
    return MedicalState.bandageChangesApplied >= MedicalState.bandageChangesNeeded
        and MedicalState.bandageChangesNeeded > 0
end

-- Reset all wound state (fully healed or admin clear)
local function ResetMedicalState()
    MedicalState.bleedingLevel = 0
    MedicalState.bandageChangesNeeded = 0
    MedicalState.bandageChangesApplied = 0
    MedicalState.activeBandage = nil
    MedicalState.lastWoundSource = nil
    MedicalState.lastHitBone = 14411
    MedicalState.woundTimestamp = 0
    bandageTickThread = nil

    -- Sync to server
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', MedicalState)

    if Config.WoundSystem.debugging.enabled then
        print("^2[CORE MEDICAL] Medical state fully reset^7")
    end
end

--============================================
-- SECTION 2: WEAPON HASH RESOLUTION
--============================================

-- Resolve weapon hash from event data to a Config.WeaponDamage key
-- EVENT_NETWORK_DAMAGE_ENTITY gives us the weapon hash directly (data[6])
-- We just need to map it to our config, with animal/fall fallbacks
local function ResolveWeaponFromEvent(weaponHash, attackerEntity, isMelee)
    -- 1. Direct match in config
    if weaponHash and weaponHash ~= 0 and Config.WeaponDamage[weaponHash] then
        return weaponHash
    end

    -- 2. Melee with no known weapon = unarmed
    if isMelee then
        local unarmedHash = GetHashKey("WEAPON_UNARMED")
        if Config.WeaponDamage[unarmedHash] then
            return unarmedHash
        end
    end

    -- 3. Check if attacker is an animal
    if attackerEntity and DoesEntityExist(attackerEntity) then
        local isAnimal = GetIsAnimal(attackerEntity)
        if isAnimal then
            local model = GetEntityModel(attackerEntity)
            local animalWeaponMap = {
                [GetHashKey("a_c_wolf")] = GetHashKey("WEAPON_WOLF"),
                [GetHashKey("a_c_coyote_01")] = GetHashKey("WEAPON_WOLF"),
                [GetHashKey("a_c_cougar")] = GetHashKey("WEAPON_COUGAR"),
                [GetHashKey("a_c_panther_01")] = GetHashKey("WEAPON_COUGAR"),
                [GetHashKey("a_c_bear_01")] = GetHashKey("WEAPON_BEAR"),
                [GetHashKey("a_c_bearblack_01")] = GetHashKey("WEAPON_BEAR"),
                [GetHashKey("a_c_snake_01")] = GetHashKey("WEAPON_SNAKE"),
                [GetHashKey("a_c_alligator_01")] = GetHashKey("WEAPON_ANIMAL"),
                [GetHashKey("a_c_horse_01")] = GetHashKey("WEAPON_HORSE"),
            }
            local resolved = animalWeaponMap[model]
            if resolved and Config.WeaponDamage[resolved] then
                return resolved
            end
            -- Generic animal fallback
            local genericAnimal = GetHashKey("WEAPON_ANIMAL")
            if Config.WeaponDamage[genericAnimal] then
                return genericAnimal
            end
        end
    end

    -- 4. Fall damage check (ragdoll state)
    local playerPed = PlayerPedId()
    if IsPedRagdoll(playerPed) then
        local fallHash = GetHashKey("WEAPON_FALL")
        if Config.WeaponDamage[fallHash] then
            return fallHash
        end
    end

    -- 5. No match found
    return nil
end

--============================================
-- SECTION 3: DAMAGE DETECTION (EVENT_NETWORK_DAMAGE_ENTITY)
--============================================
-- Uses RedM game event directly - no polling, no ped scanning
-- Event data indices (0-based in event, 1-based in Lua table):
--   data[1]  = damaged entity id (victim)
--   data[2]  = killer/damager entity id
--   data[3]  = damage amount
--   data[4]  = isVictimDestroyed
--   data[5]  = isVictimIncapacitated
--   data[6]  = WeaponUsed hash
--   data[7]  = AmmoUsed hash
--   data[8]  = InstigatedWeaponUsed
--   data[9]  = VictimSpeed
--   data[10] = DamagerSpeed
--   data[11] = IsResponsibleForCollision
--   data[12] = IsHeadShot
--   data[13] = IsWithMeleeWeapon
--   data[14] = IsVictimExecuted
--   data[15] = VictimBledOut
--   data[32] = IsSuicide

local function ProcessDamageEvent(data)
    if ApplyingMedicalDamage then return end

    -- Cooldown check
    local currentTime = GetGameTimer()
    if currentTime - LastDamageTime < DAMAGE_COOLDOWN then return end
    LastDamageTime = currentTime

    -- Skip self-inflicted damage
    if data.isSuicide then return end

    -- Resolve weapon hash to config entry
    local resolvedWeapon = ResolveWeaponFromEvent(data.weaponHash, data.attacker, data.isMelee)

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^5  Resolved weapon: %s (from hash: %d)^7",
            resolvedWeapon and Config.WeaponDamage[resolvedWeapon] and Config.WeaponDamage[resolvedWeapon].data or "NONE",
            data.weaponHash or 0))
    end

    if not resolvedWeapon then
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^3[DAMAGE] Unknown weapon hash %d - no medical effect^7", data.weaponHash or 0))
        end
        return
    end

    -- Get weapon configuration
    local weaponData = Config.WeaponDamage[resolvedWeapon]

    -- Roll bleeding chance
    local bleedChance = weaponData.chance or 0
    if bleedChance <= 0 or math.random() > bleedChance then
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^3[DAMAGE] %s hit - no bleeding (chance: %.0f%%, rolled fail)^7",
                weaponData.data or "unknown", bleedChance * 100))
        end
        return
    end

    -- Add global bleeding
    local bleedingAmount = weaponData.bleeding or 1

    -- Headshot bonus bleeding
    if data.isHeadShot then
        bleedingAmount = math.min(bleedingAmount * 1.5, 10)
    end

    MedicalState.bleedingLevel = math.min(MedicalState.bleedingLevel + bleedingAmount, 10)

    -- Add bandage changes needed (stacks with each hit)
    local bandageChanges = weaponData.bandageChanges or 2
    MedicalState.bandageChangesNeeded = MedicalState.bandageChangesNeeded + bandageChanges

    -- Track last hit bone for wound effects
    local _, lastBone = GetPedLastDamageBone(PlayerPedId())
    if lastBone and lastBone > 0 then
        MedicalState.lastHitBone = lastBone
    end

    -- Track wound source
    MedicalState.lastWoundSource = weaponData.data or "unknown"
    if MedicalState.woundTimestamp == 0 then
        MedicalState.woundTimestamp = currentTime
    end

    -- Sync to server
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', MedicalState)

    -- Notify player
    lib.notify({
        title = locale('cl_menu_medical_warning'),
        description = string.format("You're bleeding! (Level: %.1f/10)", MedicalState.bleedingLevel),
        type = 'error',
        duration = 5000
    })

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[DAMAGE] Hit by %s%s - Bleeding: %.1f/10, Bandages needed: %d^7",
            weaponData.data or "unknown",
            data.isHeadShot and " (HEADSHOT)" or "",
            MedicalState.bleedingLevel, MedicalState.bandageChangesNeeded))
    end
end

-- ============================================================
-- DAMAGE EVENT POLLING (EVENT_NETWORK_DAMAGE_ENTITY)
-- ============================================================
-- Uses native event queue (group 1 = network events)
-- DataView library required for reading struct buffer data
-- Event fields (32 total, each at 8-byte offset):
--   [0]  damaged entity id (victim)      [1]  killer entity id
--   [2]  damage amount                   [3]  isVictimDestroyed
--   [4]  isVictimIncapacitated           [5]  WeaponUsed hash
--   [6]  AmmoUsed hash                   [7]  InstigatedWeaponUsed
--   [8]  VictimSpeed                     [9]  DamagerSpeed
--   [10] IsResponsibleForCollision       [11] IsHeadShot
--   [12] IsWithMeleeWeapon               [13] IsVictimExecuted
--   [14] VictimBledOut                   [15] DamagerWasScopedIn
--   [16] DamagerSpecialAbilityActive     [17] VictimHogtied
--   [18] VictimMounted                   [19] VictimInVehicle
--   [20] VictimInCover                   [21] DamagerShotLastBullet
--   [22] VictimKilledByStealth           [23] VictimKilledByTakedown
--   [24] VictimKnockedOut                [25] isVictimTranquilized
--   [26] VictimKilledByStandardMelee     [27] VictimMissionEntity
--   [28] VictimFleeing                   [29] VictimInCombat
--   [30] unknown                         [31] IsSuicide

local DAMAGE_EVENT_HASH = GetHashKey("EVENT_NETWORK_DAMAGE_ENTITY")
local DAMAGE_DATA_SIZE = 32
local DAMAGE_BUF_SIZE = 8 * DAMAGE_DATA_SIZE -- 256 bytes

CreateThread(function()
    if Config.WoundSystem.debugging.enabled then
        print("^2[CORE MEDICAL] Damage event polling thread started (native event queue group 1)^7")
    end

    while true do
        Wait(0)

        local eventCount = GetNumberOfEvents(1)
        if eventCount > 0 then
            for i = 0, eventCount - 1 do
                local eventHash = GetEventAtIndex(1, i)

                if eventHash == DAMAGE_EVENT_HASH then
                    -- Create buffer and read event data
                    local buf = DataView.ArrayBuffer(DAMAGE_BUF_SIZE)
                    local hasData = Citizen.InvokeNative(0x57EC5FA4D4D6AFCA, 1, i, buf:Buffer(), DAMAGE_DATA_SIZE)

                    if hasData then
                        local myPed = PlayerPedId()
                        local victim = buf:GetInt32(0)

                        -- Only process if WE are the victim
                        if victim == myPed then
                            local attacker   = buf:GetInt32(8)
                            local damage     = buf:GetInt32(16)
                            local destroyed  = buf:GetInt32(24)
                            local incap      = buf:GetInt32(32)
                            local weaponHash = buf:GetInt32(40)
                            local ammoHash   = buf:GetInt32(48)
                            local isHeadShot = buf:GetInt32(88)  -- index 11
                            local isMelee    = buf:GetInt32(96)  -- index 12
                            local isSuicide  = buf:GetInt32(248) -- index 31

                            -- Debug output
                            if Config.WoundSystem.debugging.enabled then
                                print("^5=== EVENT_NETWORK_DAMAGE_ENTITY (we are victim) ===^7")
                                print(string.format("^5  Victim: %d | Attacker: %d | Damage: %d^7", victim, attacker, damage))
                                print(string.format("^5  WeaponHash: %d | AmmoHash: %d^7", weaponHash, ammoHash))
                                print(string.format("^5  HeadShot: %d | Melee: %d | Suicide: %d^7", isHeadShot, isMelee, isSuicide))
                                print(string.format("^5  Destroyed: %d | Incapacitated: %d^7", destroyed, incap))
                            end

                            -- Pass to damage processor
                            ProcessDamageEvent({
                                victim = victim,
                                attacker = attacker,
                                damage = damage,
                                weaponHash = weaponHash,
                                ammoHash = ammoHash,
                                isHeadShot = isHeadShot == 1,
                                isMelee = isMelee == 1,
                                isSuicide = isSuicide == 1,
                                isDestroyed = destroyed == 1,
                                isIncapacitated = incap == 1,
                            })
                        end
                    end
                end
            end
        end
    end
end)

--============================================
-- SECTION 4: BANDAGE APPLICATION (Simplified)
--============================================

-- Apply bandage (global - no body part needed)
function ApplyBandage(bandageType, appliedBy)
    local bandageConfig = Config.BandageTypes[bandageType]
    if not bandageConfig then
        print("[ERROR] Unknown bandage type: " .. tostring(bandageType))
        return false
    end

    -- Check if player is wounded
    if not IsWounded() then
        lib.notify({
            title = locale('cl_menu_treatment'),
            description = "You have no wounds to bandage.",
            type = 'error',
            duration = 5000
        })
        return false
    end

    -- Check if bandage already active
    if MedicalState.activeBandage then
        lib.notify({
            title = locale('cl_menu_treatment_error'),
            description = "A bandage is already active. Wait for it to expire or remove it first.",
            type = 'error',
            duration = 5000
        })
        return false
    end

    local ped = PlayerPedId()

    -- 1. INSTANT HEAL: Apply immediate % health restoration
    local healPercent = bandageConfig.instantHealPercent or 25
    local healAmount = math.floor(Config.MaxHealth * healPercent / 100)
    local currentHealth = GetEntityHealth(ped)
    local newHealth = math.min(currentHealth + healAmount, Config.MaxHealth)
    SetEntityHealth(ped, newHealth)

    -- 2. REDUCE BLEEDING
    local bleedingReduction = bandageConfig.bleedingReduction or 2
    MedicalState.bleedingLevel = math.max(MedicalState.bleedingLevel - bleedingReduction, 0)

    -- 3. TRACK BANDAGE
    local currentTime = GetGameTimer()
    local durationMs = (bandageConfig.duration or 5) * 60 * 1000
    MedicalState.activeBandage = {
        type = bandageType,
        appliedTime = currentTime,
        expirationTime = currentTime + durationMs,
        config = bandageConfig,
        appliedBy = appliedBy,
    }

    -- 4. INCREMENT BANDAGE CHANGES (by healingPower - better bandages heal more per use)
    local healingPower = bandageConfig.healingPower or 1
    MedicalState.bandageChangesApplied = MedicalState.bandageChangesApplied + healingPower

    -- 5. CHECK IF FULLY HEALED
    if MedicalState.bandageChangesApplied >= MedicalState.bandageChangesNeeded and MedicalState.bandageChangesNeeded > 0 then
        -- Let the bandage tick finish its duration for the health regen,
        -- but mark bleeding as fully stopped
        MedicalState.bleedingLevel = 0

        lib.notify({
            title = "Wound Healed",
            description = "Your wounds are fully treated! Keep the bandage on for continued healing.",
            type = 'success',
            duration = 7000
        })

        if Config.WoundSystem.debugging.enabled then
            print("^2[BANDAGE] Fully healed! All bandage changes completed.^7")
        end
    end

    -- 6. START HEALTH TICK THREAD
    local tickInterval = (bandageConfig.tickInterval or 10) * 1000
    local healthPerTick = bandageConfig.healthPerTick or 5
    local bandageRef = MedicalState.activeBandage -- capture reference

    bandageTickThread = CreateThread(function()
        while MedicalState.activeBandage == bandageRef do
            Wait(tickInterval)

            -- Check if bandage still active
            if MedicalState.activeBandage ~= bandageRef then break end

            -- Check if expired
            if GetGameTimer() >= bandageRef.expirationTime then
                -- Bandage expired
                MedicalState.activeBandage = nil
                bandageTickThread = nil

                -- If not fully healed, notify about infection risk
                if not IsFullyHealed() then
                    lib.notify({
                        title = "Bandage Expired",
                        description = string.format("Your %s has expired! Apply a new bandage. (%d/%d changes)",
                            bandageConfig.label, MedicalState.bandageChangesApplied, MedicalState.bandageChangesNeeded),
                        type = 'warning',
                        duration = 7000
                    })
                else
                    -- Fully healed, bandage expired naturally - clean up
                    ResetMedicalState()
                    lib.notify({
                        title = "Fully Recovered",
                        description = "Your wounds have completely healed.",
                        type = 'success',
                        duration = 5000
                    })
                end

                if Config.WoundSystem.debugging.enabled then
                    print("^3[BANDAGE] Expired - infection risk increases^7")
                end
                break
            end

            -- Apply health tick
            local pedNow = PlayerPedId()
            local currentHP = GetEntityHealth(pedNow)
            if currentHP < Config.MaxHealth then
                local tickHeal = math.min(healthPerTick, Config.MaxHealth - currentHP)
                SetEntityHealth(pedNow, currentHP + tickHeal)
            end
        end
    end)

    -- Sync to server
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', MedicalState)

    -- Notify player
    lib.notify({
        title = locale('cl_menu_treatment'),
        description = string.format("%s applied! +%d%% health. (%d/%d bandage changes)",
            bandageConfig.label, healPercent, MedicalState.bandageChangesApplied, MedicalState.bandageChangesNeeded),
        type = 'success',
        duration = 5000
    })

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[BANDAGE] %s applied - Bleeding: %.1f, Changes: %d/%d^7",
            bandageConfig.label, MedicalState.bleedingLevel,
            MedicalState.bandageChangesApplied, MedicalState.bandageChangesNeeded))
    end

    return true
end

--============================================
-- SECTION 5: TOURNIQUET (Already global - minimal changes)
--============================================

-- Apply tourniquet treatment (global application - stops all bleeding)
function ApplyTourniquet(tourniquetType, appliedBy)
    local tourniquetConfig = Config.TourniquetTypes[tourniquetType]
    if not tourniquetConfig then
        print("[ERROR] Unknown tourniquet type: " .. tostring(tourniquetType))
        return false
    end

    -- Check if bleeding
    if MedicalState.bleedingLevel <= 0 then
        lib.notify({
            title = locale('cl_menu_treatment'),
            description = locale('cl_desc_no_bleeding_wounds'),
            type = 'error',
            duration = 5000
        })
        return false
    end

    -- Check if tourniquet already active
    if LocalPlayer.state.tourniquet and LocalPlayer.state.tourniquet > GetGameTimer() then
        lib.notify({
            title = locale('cl_menu_treatment_error'),
            description = locale('cl_desc_tourniquet_already_active'),
            type = 'error',
            duration = 5000
        })
        return false
    end

    -- Apply tourniquet globally
    local currentTime = GetGameTimer()
    local duration = (tourniquetConfig.maxDuration or 30) * 60 * 1000
    local expirationTime = currentTime + duration

    LocalPlayer.state:set('tourniquet', expirationTime, false)

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
local function RemoveTourniquet(reason)
    LocalPlayer.state:set('tourniquet', nil, false)

    lib.notify({
        title = locale('cl_menu_treatment'),
        description = string.format(locale('cl_desc_fmt_tourniquet_removed'), reason or "expired"),
        type = 'inform',
        duration = 5000
    })

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^3[TOURNIQUET] Removed: %s^7", reason or "expired"))
    end
    return true
end

--============================================
-- SECTION 6: MEDICINE & INJECTIONS (Unchanged)
--============================================

-- Administer medicine (heals HP + temporary effects)
function AdministreMedicine(medicineType, appliedBy)
    local medicineConfig = Config.MedicineTypes[medicineType]
    if not medicineConfig then
        print("[ERROR] Unknown medicine type: " .. tostring(medicineType))
        return false
    end

    -- Prevent stacking same medicine
    if MedicalState.medicineEffects[medicineType] and MedicalState.medicineEffects[medicineType] > GetGameTimer() then
        lib.notify({
            title = locale('cl_menu_treatment_error'),
            description = string.format(locale('cl_desc_fmt_medicine_already_active'), medicineConfig.label or medicineType),
            type = 'error',
            duration = 5000
        })
        return false
    end

    local ped = PlayerPedId()
    local currentTime = GetGameTimer()
    local durationMs = (medicineConfig.duration or 300) * 1000

    -- Apply immediate healing
    if medicineConfig.healAmount and medicineConfig.healAmount > 0 then
        local currentHealth = GetEntityHealth(ped)
        local newHealth = math.min(currentHealth + medicineConfig.healAmount, Config.MaxHealth or 600)
        SetEntityHealth(ped, newHealth)
    end

    -- Track medicine effect
    MedicalState.medicineEffects[medicineType] = currentTime + durationMs

    -- Morphine/laudanum bypass movement penalties
    if medicineType == 'morphine' or medicineType == 'laudanum' then
        MedicalState.medicineEffects.morphine_effect = currentTime + durationMs
    end

    lib.notify({
        title = locale('cl_menu_treatment'),
        description = string.format(locale('cl_desc_fmt_medicine_taken'), medicineConfig.label or medicineType),
        type = 'success',
        duration = 5000
    })

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[MEDICINE] %s applied - heal:%d, duration:%ds^7",
            medicineConfig.label, medicineConfig.healAmount or 0, medicineConfig.duration or 0))
    end

    -- Expiration thread
    CreateThread(function()
        Wait(durationMs)
        MedicalState.medicineEffects[medicineType] = nil

        if (medicineType == 'morphine' or medicineType == 'laudanum') then
            if not MedicalState.medicineEffects.morphine_effect or MedicalState.medicineEffects.morphine_effect <= GetGameTimer() then
                MedicalState.medicineEffects.morphine_effect = nil
            end
        end

        lib.notify({
            title = locale('cl_menu_treatment'),
            description = string.format(locale('cl_desc_fmt_medicine_expired'), medicineConfig.label or medicineType),
            type = 'warning',
            duration = 5000
        })
    end)

    return true
end

-- Give injection
function GiveInjection(injectionType, appliedBy)
    local injectionConfig = Config.InjectionTypes[injectionType]
    if not injectionConfig then
        print("[ERROR] Unknown injection type: " .. tostring(injectionType))
        return false
    end

    -- Prevent stacking
    if MedicalState.injectionEffects[injectionType] and MedicalState.injectionEffects[injectionType] > GetGameTimer() then
        lib.notify({
            title = locale('cl_menu_treatment_error'),
            description = string.format(locale('cl_desc_fmt_injection_already_active'), injectionConfig.label or injectionType),
            type = 'error',
            duration = 5000
        })
        return false
    end

    local ped = PlayerPedId()
    local currentTime = GetGameTimer()
    local durationMs = (injectionConfig.duration or 120) * 1000

    -- Overdose risk
    local overdoseRisk = injectionConfig.overdoseRisk or 0
    if overdoseRisk > 0 and math.random(100) <= overdoseRisk then
        local overDmg = math.floor((injectionConfig.healAmount or 20) * 0.5)
        ApplyDamageToPed(ped, overDmg, false)
        PlayPain(ped, 9, 1, true, true)

        lib.notify({
            title = locale('cl_menu_medical_warning'),
            description = string.format(locale('cl_desc_fmt_injection_overdose'), injectionConfig.label or injectionType),
            type = 'error',
            duration = 10000
        })
        return false
    end

    -- Apply healing
    if injectionConfig.healAmount and injectionConfig.healAmount > 0 then
        local currentHealth = GetEntityHealth(ped)
        local newHealth = math.min(currentHealth + injectionConfig.healAmount, Config.MaxHealth or 600)
        SetEntityHealth(ped, newHealth)
    end

    MedicalState.injectionEffects[injectionType] = currentTime + durationMs

    -- Adrenaline effect
    if injectionType == 'adrenaline' then
        MedicalState.medicineEffects.morphine_effect = currentTime + durationMs
    end

    lib.notify({
        title = locale('cl_menu_treatment'),
        description = string.format(locale('cl_desc_fmt_injection_given'), injectionConfig.label or injectionType),
        type = 'success',
        duration = 5000
    })

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[INJECTION] %s administered - heal:%d, duration:%ds^7",
            injectionConfig.label, injectionConfig.healAmount or 0, injectionConfig.duration or 0))
    end

    -- Expiration thread
    CreateThread(function()
        Wait(durationMs)
        MedicalState.injectionEffects[injectionType] = nil

        if injectionType == 'adrenaline' then
            if not MedicalState.medicineEffects.morphine_effect or MedicalState.medicineEffects.morphine_effect <= GetGameTimer() then
                MedicalState.medicineEffects.morphine_effect = nil
            end
        end

        lib.notify({
            title = locale('cl_menu_treatment'),
            description = string.format(locale('cl_desc_fmt_injection_expired'), injectionConfig.label or injectionType),
            type = 'warning',
            duration = 5000
        })
    end)

    return true
end

--============================================
-- SECTION 7: BACKGROUND THREADS
--============================================

-- Bleeding damage loop (applies damage from untreated bleeding every 30 seconds)
CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.isLoggedIn
    Wait(5000)

    if Config.WoundSystem.debugging.enabled then
        print("^2[CORE MEDICAL] Bleeding damage loop started (30s intervals)^7")
    end

    while true do
        Wait(30000) -- 30 seconds

        if not LocalPlayer.state.isLoggedIn then goto continue_loop end

        local playerData = RSGCore.Functions.GetPlayerData()
        if not playerData or playerData.metadata.isdead then goto continue_loop end

        -- No bleeding = no damage
        if MedicalState.bleedingLevel <= 0 then goto continue_loop end

        -- Tourniquet active = no bleeding damage
        local tourniquetActive = LocalPlayer.state.tourniquet and LocalPlayer.state.tourniquet > GetGameTimer()
        if tourniquetActive then goto continue_loop end

        -- Active bandage = no bleeding damage (bandage is protecting)
        if MedicalState.activeBandage then goto continue_loop end

        -- Apply bleeding damage based on level
        local bleedLevel = math.floor(MedicalState.bleedingLevel)
        bleedLevel = math.max(1, math.min(bleedLevel, 10))
        local injuryState = Config.InjuryStates[bleedLevel]

        if injuryState and injuryState.bleedingDamagePerTick then
            local ped = PlayerPedId()
            ApplyingMedicalDamage = true
            PlayPain(ped, 9, 1, true, true)
            ApplyDamageToPed(ped, math.floor(injuryState.bleedingDamagePerTick), false)
            ApplyingMedicalDamage = false

            -- Stomach blood effect for heavy bleeding (level 4+)
            if bleedLevel >= 4 then
                local pressure = 0.1 + (bleedLevel - 4) * 0.05
                local fountain = 3.0 + (bleedLevel - 4) * 1.0
                SetPedActivateWoundEffect(ped, 0, 2, 14411, 0.0, pressure, 0.0, 0.0, fountain, -1.0, 1.0)
            end

            lib.notify({
                title = locale('cl_menu_medical_warning'),
                description = string.format("You're bleeding! (Level %.1f/10) - Apply a bandage!", MedicalState.bleedingLevel),
                type = 'error',
                duration = 7000
            })
        end

        -- Bleeding worsens over time if untreated
        if Config.WoundProgression and Config.WoundProgression.bleedingProgressAmount then
            MedicalState.bleedingLevel = math.min(
                MedicalState.bleedingLevel + Config.WoundProgression.bleedingProgressAmount,
                10
            )
        end

        ::continue_loop::
    end
end)

-- Tourniquet expiration handler
CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.isLoggedIn

    while true do
        Wait(5000)

        local tourniquetExpiry = LocalPlayer.state.tourniquet
        if tourniquetExpiry and tourniquetExpiry <= GetGameTimer() then
            LocalPlayer.state:set('tourniquet', nil, false)

            lib.notify({
                title = locale('cl_menu_tourniquet_expired'),
                description = locale('cl_desc_tourniquet_wore_off'),
                type = 'warning',
                duration = 5000
            })

            if Config.WoundSystem.debugging.enabled then
                print("^3[TOURNIQUET] Expired - bleeding may resume^7")
            end
        end
    end
end)

-- Movement-based bleeding acceleration
CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.isLoggedIn

    local prevPos = GetEntityCoords(PlayerPedId())

    while true do
        Wait(3000)

        if MedicalState.bleedingLevel <= 0 then
            prevPos = GetEntityCoords(PlayerPedId())
            goto continue_movement
        end

        if not IsPedInAnyVehicle(PlayerPedId()) then
            local currPos = GetEntityCoords(PlayerPedId())
            local distance = #(vector2(prevPos.x, prevPos.y) - vector2(currPos.x, currPos.y))

            if distance > 1.0 then
                local moveChance = Config.WoundProgression and Config.WoundProgression.movementBleedingChance or 0.05
                local moveAmount = Config.WoundProgression and Config.WoundProgression.movementBleedingAmount or 0.5

                if math.random() < moveChance then
                    MedicalState.bleedingLevel = math.min(MedicalState.bleedingLevel + moveAmount, 10)

                    if Config.WoundSystem.debugging.enabled then
                        print(string.format("^1[MOVEMENT] Bleeding worsened to %.1f^7", MedicalState.bleedingLevel))
                    end
                end

                if math.random() < 0.1 then
                    lib.notify({
                        title = locale('cl_menu_medical_warning'),
                        description = locale('cl_desc_movement_bleeding_warning'),
                        type = 'error',
                        duration = 5000
                    })
                end
            end

            prevPos = currPos
        else
            prevPos = GetEntityCoords(PlayerPedId())
        end

        ::continue_movement::
    end
end)

--============================================
-- SECTION 8: ADDITIONAL FUNCTIONS
--============================================

-- Add bleeding from environmental sources (falls, etc.)
local function AddFallBleeding(amount)
    if not amount or amount <= 0 then return end
    MedicalState.bleedingLevel = math.min(MedicalState.bleedingLevel + amount, 10)
    MedicalState.bandageChangesNeeded = MedicalState.bandageChangesNeeded + 1
    if MedicalState.woundTimestamp == 0 then
        MedicalState.woundTimestamp = GetGameTimer()
    end
    MedicalState.lastWoundSource = "Fall"
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', MedicalState)
end

--============================================
-- SECTION 9: EXPORTS
--============================================

local MEDICAL = {
    -- State access
    GetState = GetMedicalState,
    GetMedicalState = GetMedicalState,
    IsWounded = IsWounded,
    IsFullyHealed = IsFullyHealed,
    ResetMedicalState = ResetMedicalState,

    -- Treatment operations
    ApplyBandage = ApplyBandage,
    ApplyTourniquet = ApplyTourniquet,
    AdministreMedicine = AdministreMedicine,
    GiveInjection = GiveInjection,
    RemoveTourniquet = RemoveTourniquet,

    -- Environmental
    AddFallBleeding = AddFallBleeding,
}

-- Register all methods on QCMed global table (zero-overhead intra-resource calls)
for key, value in pairs(MEDICAL) do
    if type(value) == "function" then
        QCMed[key] = value
    end
end

-- Keep external exports for cross-resource access
exports('IsWounded', IsWounded)
exports('GetMedicalState', GetMedicalState)

if Config.WoundSystem.debugging.enabled then
    print("^2[CORE MEDICAL] Simplified system initialized - Global bleeding + bandage cycles^7")
end
