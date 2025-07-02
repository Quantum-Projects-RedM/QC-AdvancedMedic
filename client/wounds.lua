local isBleeding = 0
local advanceBleedTimer = 0
local blackoutTimer = 0
local onMorphine = 0
local wasOnMorphine = false
local onDrugs = 0
local wasOnDrugs = false
local legCount = 0
local armCount = 0
local headCount = 0
local playerHealth = nil
local screenEffects = false
local injuredParts = {}
local MovementRate = { 0.98, 0.96, 0.94, 0.92 }

lib.locale()

---
-- ApplyBleedingByWeapon
-- Determines how much the bleeding value should increase based on the weapon type.
-- Light and medium weapons cause minor bleeding (1 point).
-- Heavy and high-caliber weapons may cause more bleeding (up to 2 points).
-- Bleeding is capped at 4.
-- @param weapon integer Weapon class defined in Config.WeaponClasses
local function ApplyBleedingByWeapon(weapon)
    local increase = 0
    if weapon == Config.WeaponClasses['SMALL_CALIBER'] or weapon == Config.WeaponClasses['MEDIUM_CALIBER'] or
       weapon == Config.WeaponClasses['CUTTING'] or weapon == Config.WeaponClasses['WILDLIFE'] or
       weapon == Config.WeaponClasses['OTHER'] or weapon == Config.WeaponClasses['LIGHT_IMPACT'] then
        increase = 1
    elseif weapon == Config.WeaponClasses['HIGH_CALIBER'] or weapon == Config.WeaponClasses['HEAVY_IMPACT'] or
           weapon == Config.WeaponClasses['SHOTGUN'] or weapon == Config.WeaponClasses['EXPLOSIVE'] then
        increase = (isBleeding < 3) and 2 or 1
    end
    isBleeding = math.min(isBleeding + increase, 4)
end

local function ResetInjuries()
    for k, v in pairs(Config.BodyParts) do
        v.isDamaged = false
        v.severity = 0
    end
    injuredParts = {}
end

function GetDamagingWeapon(ped)
    for k, v in pairs(Config.weapons) do
        if HasPedGotWeapon(ped, k, false) then
            ClearEntityLastDamageEntity(ped)
            return v
        end
    end

    return nil
end
---
-- Applies movement limitations and morphine logic
-- Slows player movement depending on limb injuries unless morphine is active
function ProcessRunStuff(ped)
    local hasLegInjury = false
    for k, v in pairs(Config.BodyParts) do
        if v.causeLimp and v.isDamaged then
            hasLegInjury = true
            break
        end
    end

    if hasLegInjury and onMorphine <= 0 then
        local level = 0
        for k, v in pairs(injuredParts) do
            if v.severity > level then
                level = v.severity
            end
        end
        SetPedMoveRateOverride(ped, MovementRate[level])
        if wasOnMorphine then
            SetPedToRagdoll(ped, 1500, 2000, 3, true, true, false)
            wasOnMorphine = false
            lib.notify({ title = locale('qc_health'), description = locale('qc_notGood'), type = 'success' })
        end
    else
        SetPedMoveRateOverride(ped, 1.0)
        if not wasOnMorphine and onMorphine > 0 then
            wasOnMorphine = true
            lib.notify({ title = locale('qc_health'), description = locale('qc_painfade'), type = 'success' })
        end
        if onMorphine > 0 then
            onMorphine = onMorphine - 1
        end
    end
end

---
-- Processes effects based on injuries like head trauma or leg collapse
function ProcessDamage(ped)
    for k, v in pairs(injuredParts) do
        if (k == 'LLEG' or k == 'RLEG') and v.severity >= 1 then
            legCount = legCount + 1
            if legCount >= 15 then
                legCount = 0
                local chance = math.random(100)
                if IsPedRunning(ped) or IsPedSprinting(ped) then
                    if chance <= 50 then
                        lib.notify({ title = locale('qc_health'), description = locale('qc_difficultyToRun'), type = 'error' })
                        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08)
                        SetPedToRagdollWithFall(ped, 1500, 2000, 1, GetEntityForwardVector(ped), 1.0, 0.0, 0.0)
                    end
                elseif chance <= 15 then
                    lib.notify({ title = locale('qc_health'), description = locale('qc_difficultyToWalk'), type = 'error' })
                    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08)
                    SetPedToRagdollWithFall(ped, 1500, 2000, 1, GetEntityForwardVector(ped), 1.0, 0.0, 0.0)
                end
            end
        elseif k == 'HEAD' and v.severity >= 2 then
            headCount = headCount + 1
            if headCount >= 30 then
                headCount = 0
                if math.random(100) <= 15 then
                    lib.notify({ title = locale('qc_health'), description = locale('qc_suddenlyFainted'), type = 'success' })
                    DoScreenFadeOut(100)
                    while not IsScreenFadedOut() do Citizen.Wait(0) end
                    if not IsPedRagdoll(ped) and IsPedOnFoot(ped) and not IsPedSwimming(ped) then
                        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08)
                        SetPedToRagdoll(ped, 5000, 1, 2)
                    end
                    Citizen.Wait(5000)
                    DoScreenFadeIn(250)
                end
            end
        end
    end

    if onDrugs > 0 then
        onDrugs = onDrugs - 1
        if onDrugs == 0 then
            wasOnDrugs = true
        end
    elseif wasOnDrugs then
        SetPedToRagdoll(ped, 1500, 2000, 3, true, true, false)
        wasOnDrugs = false
        lib.notify({ title = locale('qc_health'), description = locale('qc_notGood'), type = 'success' })
    end
end


RegisterNetEvent('qc-AdvancedMedic:SyncBleed', function(bleedStatus)
    isBleeding = tonumber(bleedStatus)
end)

RegisterNetEvent('qc-AdvancedMedic:FieldTreatLimbs', function()
    local untreated = {}
    for k, v in pairs(Config.BodyParts) do
        if v.isDamaged then
            table.insert(untreated, { part = v.label, severity = v.severity })
        end
    end
    if #untreated > 0 then
        local msg = locale('qc_needTreatment')
        for _, v in ipairs(untreated) do
            msg = msg .. locale('qc_part') .. v.part .. locale('qc_severity') .. v.severity
        end
        lib.notify({ title = locale('qc_health'), description = msg, type = 'error' })
    else
        lib.notify({ title = locale('qc_health'), description = locale('qc_neednoTreatment'), type = 'success' })
    end
end)

RegisterNetEvent('qc-AdvancedMedic:ResetLimbs', function()
    local resetParts = {}
    for k, v in pairs(Config.BodyParts) do
        if v.isDamaged then
            table.insert(resetParts, v.label)
        end
    end
    if #resetParts > 0 then
        local msg = locale('qc_partsreset')
        for _, v in ipairs(resetParts) do
            msg = msg .. locale('qc_part') .. v
        end
        lib.notify({ title = locale('qc_health'), description = msg, type = 'error' })
    else
        lib.notify({ title = locale('qc_health'), description = locale('qc_nopartbeenreset'), type = 'success' })
    end
    ResetInjuries()
end)

RegisterNetEvent('qc-AdvancedMedic:ReduceBleed', function()
    if isBleeding > 0 then
        isBleeding = isBleeding - 1
        lib.notify({ title = locale('qc_health'), description = locale('qc_leeding_reduced_state') .. isBleeding, type = 'success' })
    end
end)

RegisterNetEvent('qc-AdvancedMedic:RemoveBleed', function()
    isBleeding = 0
    lib.notify({ title = locale('qc_health'), description = locale('qc_leeding_stopped_state'), type = 'success' })
end)

RegisterNetEvent('qc-AdvancedMedic:UseMorphine', function(tier)
    if tier < 4 then
        onMorphine = 90 * tier
    end
    lib.notify({ title = locale('qc_health'), description = locale('qc_temporaryWound'), type = 'success' })
end)

RegisterNetEvent('qc-AdvancedMedic:UseDrugs', function(tier)
    if tier < 4 then
        onDrugs = 180 * tier
    end
    lib.notify({ title = locale('qc_health'), description = locale('qc_bodyFailIgnore'), type = 'success' })
end)

function CheckDamage(ped, bone, weapon)
    if not weapon or not Config.parts[bone] then return end
    local partKey = Config.parts[bone]
    local partData = Config.BodyParts[partKey]

    if not partData.isDamaged then
        partData.isDamaged = true
        partData.severity = 1
        ApplyBleedingByWeapon(weapon)
        injuredParts[partKey] = { label = partData.label, severity = partData.severity }
        lib.notify({ title = locale('qc_health'), description = locale('qc_youAreWith') .. " " .. Config.WoundStates[1] .. " " .. partData.label, type = 'success' })
    else
        ApplyBleedingByWeapon(weapon)
        if partData.severity < 4 then
            partData.severity = partData.severity + 1
            injuredParts[partKey].severity = partData.severity
        end
    end
    TriggerServerEvent('qc-AdvancedMedic:SyncWounds', { limbs = Config.BodyParts, isBleeding = isBleeding })
end

Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if not playerHealth then
            playerHealth = GetEntityHealth(ped)
        end
        local currentHealth = GetEntityHealth(ped)
        if currentHealth < playerHealth then
            local hit, bone = GetPedLastDamageBone(ped)
            if hit and Config.parts[bone] then
                local weapon = GetDamagingWeapon(ped)
                if weapon then
                    if weapon ~= Config.WeaponClasses['LIGHT_IMPACT'] then
                        AnimpostfxPlay("PlayerHealthCrackpot")
                    end
                    CheckDamage(ped, bone, weapon)
                end
            end
        end
        playerHealth = currentHealth
        ProcessRunStuff(ped)
        ProcessDamage(ped)
        Citizen.Wait(321)
    end
end)

Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if not IsEntityDead(ped) and next(injuredParts) then
            if isBleeding > 0 then
                if blackoutTimer >= 10 then
                    lib.notify({ title = locale('qc_health'), description = locale('qc_suddenlyFainted'), type = 'success' })
                    DoScreenFadeOut(500)
                    while not IsScreenFadedOut() do Citizen.Wait(0) end
                    if not IsPedRagdoll(ped) and IsPedOnFoot(ped) and not IsPedSwimming(ped) then
                        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08)
                        SetPedToRagdollWithFall(ped, 10000, 12000, 1, GetEntityForwardVector(ped), 1.0, 0.0, 0.0)
                    end
                    Citizen.Wait(5000)
                    DoScreenFadeIn(500)
                    blackoutTimer = 0
                end
                lib.notify({ title = locale('qc_health'), description = locale('qc_youAreWith') .. " " .. Config.BleedingStates[isBleeding], type = 'success' })
                local damage = isBleeding * 30
                ApplyDamageToPed(ped, damage, false)
                playerHealth = playerHealth - damage
                blackoutTimer = blackoutTimer + 1
                advanceBleedTimer = advanceBleedTimer + 1
                if advanceBleedTimer >= 10 and isBleeding < 4 then
                    isBleeding = isBleeding + 1
                    advanceBleedTimer = 0
                end
            end
        end
        Citizen.Wait(30000)
    end
end)


