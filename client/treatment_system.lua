--=========================================================
-- QC-ADVANCED MEDIC - TREATMENT SYSTEM
--=========================================================
-- This file handles all medical treatments: bandages, tourniquets, medicines, injections
-- Uses Config.BandageTypes, Config.TourniquetTypes, Config.MedicineTypes, Config.InjectionTypes
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

-- Treatment tracking data
ActiveTreatments = {}
local TourniquetTimers = {}
local MedicineEffects = {}
local InjectionEffects = {}

--=========================================================
-- TREATMENT DATA STRUCTURES
--=========================================================
-- ActiveTreatments[bodyPart] = {
--     treatmentType = "bandage", -- bandage, tourniquet, medicine, injection
--     itemType = "cotton", -- specific item used
--     appliedTime = os.time(),
--     effectiveness = 80, -- current effectiveness
--     duration = 1800, -- total duration (for tourniquets)
--     appliedBy = serverId, -- who applied it
--     metadata = {}
-- }

--=========================================================
-- NEW BANDAGE SYSTEM - One-time Application with Decay
--=========================================================
function ApplyBandage(bodyPart, bandageType, appliedBy)
    print("Applying bandage:", bodyPart, bandageType, appliedBy)

    local bandageConfig = Config.BandageTypes[bandageType]
    if not bandageConfig then
        print("[ERROR] Unknown bandage type: " .. tostring(bandageType))
        return false
    end
    
    local bodyPartConfig = Config.BodyParts[string.upper(bodyPart)] or Config.BodyParts[bodyPart]
    if not bodyPartConfig then
        print("[ERROR] Unknown body part: " .. tostring(bodyPart))
        return false
    end
    
    -- Get current wounds for this body part
    local wounds = PlayerWounds or {}
    local wound = wounds[bodyPart]
    local bleadingLevel = wound and tonumber(wound.bleedingLevel) or 0
    local painLevel = wound and tonumber(wound.painLevel) or 0
    
    -- Check if wound exists
    if not wound then
        lib.notify({
            title = locale('cl_menu_treatment'),
            description = string.format(locale('cl_desc_fmt_no_injury_detected'), bodyPartConfig.label),
            type = 'error',
            duration = 5000
        })
        return false
    end
    
    -- Check if wound is bleeding (bandages only work on bleeding wounds)
    print(bleadingLevel)
    if not bleadingLevel or bleadingLevel <= 0 then
        lib.notify({
            title = locale('cl_menu_treatment'),
            description = string.format(locale('cl_desc_fmt_no_bleeding_detected'), bodyPartConfig.label),
            type = 'error',
            duration = 5000
        })
        return false
    end
    
    -- Check if bandage already applied to this body part
    if ActiveTreatments[bodyPart] and ActiveTreatments[bodyPart].treatmentType == "bandage" then
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
    
    -- SIMPLIFIED TIME-BASED BANDAGE SYSTEM
    -- Store original wound levels for 50% return when bandage expires
    local originalPain = painLevel
    local originalBleeding = bleadingLevel
    
    -- BLEEDING REDUCTION (immediate effect)
    local bleedingReduction = 0
    if bleadingLevel > 0 and bandageConfig.bleedingReduction then
        bleedingReduction = bandageConfig.bleedingReduction
        -- Apply reduction but maintain minimum level 1 (wounds don't vanish)
        bleadingLevel = math.max(bleadingLevel - bleedingReduction, 1)
    end
    
    -- PAIN REDUCTION (proportional to bleeding reduction since pain = bleeding + tissue damage)
    local painReduction = 0
    if bleedingReduction > 0 and painLevel > 0 then
        -- Pain reduces proportionally to bleeding (since pain is related to bleeding)
        -- But maintain minimum level 2 (tissue damage persists)
        painReduction = bleedingReduction
        painLevel = math.max(painLevel - painReduction, 2)
    end
    
    -- Update wound data on server
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', wounds)
    
    if Config.WoundSystem.debugging.enabled then
        print(string.format("^3[BANDAGE] Pain:%.1f→%.1f Bleed:%.1f→%.1f^7", 
            originalPain or 0, painLevel or 0, originalBleeding or 0, bleadingLevel or 0))
    end
    
    -- SIMPLIFIED TIME-BASED BANDAGE TRACKING
    local currentTime = GetGameTimer()
    local expirationTime = currentTime + (bandageConfig.decayRate * 60 * 1000) -- Convert minutes to milliseconds
    
    ActiveTreatments[bodyPart] = {
        treatmentType = "bandage",
        itemType = bandageType,
        appliedTime = currentTime,
        expirationTime = expirationTime,
        appliedBy = appliedBy or GetPlayerServerId(PlayerId()),
        -- Store original wound levels for 50% return when bandage expires
        originalPainLevel = originalPain,
        originalBleedingLevel = originalBleeding,
        painReduction = painReduction,
        bleedingReduction = bleedingReduction,
        isActive = true, -- Simple active/expired state
        metadata = {
            label = bandageConfig.label,
            description = bandageConfig.description,
            originalEffectiveness = bandageConfig.effectiveness,
            bleedingReduced = bandageConfig.bleedingReduction,
            immediateHeal = bandageConfig.oneTimeHeal
        }
    }
    
    -- Register bandage with infection system for decay tracking
    AddBandage(bodyPart, bandageType, {
        effectiveness = bandageConfig.effectiveness,
        decayRate = bandageConfig.decayRate,
        appliedTime = currentTime
    })
    
    -- Update server with treatment data
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateTreatmentData', ActiveTreatments)
    
    -- Success notification with detailed info
    lib.notify({
        title = locale('cl_menu_bandage_applied'),
        description = string.format(locale('cl_desc_fmt_bandage_applied_stats'),
            bandageConfig.label,
            bodyPartConfig.label,
            bandageConfig.oneTimeHeal,
            bandageConfig.bleedingReduction,
            bandageConfig.decayRate
        ),
        type = 'success',
        duration = 8000
    })
    
    return true
end

--=========================================================
-- TOURNIQUET TIMER SYSTEM
--=========================================================
local function StartTourniquetTimer(bodyPart, tourniquetType)
    if TourniquetTimers[bodyPart] then
        TourniquetTimers[bodyPart] = nil -- Clear existing timer
    end
    
    TourniquetTimers[bodyPart] = CreateThread(function()
        local treatment = ActiveTreatments[bodyPart]
        if not treatment or treatment.treatmentType ~= "tourniquet" then return end
        
        local tourniquetConfig = Config.TourniquetTypes[tourniquetType]
        local startTime = treatment.appliedTime
        local maxDuration = treatment.duration
        local warningTime = Config.Tourniquet.warningTime or (maxDuration * 0.75)
        local damageInterval = Config.Tourniquet.damageInterval or 60
        
        while ActiveTreatments[bodyPart] and ActiveTreatments[bodyPart].treatmentType == "tourniquet" do
            local currentTime = GetGameTimer()
            local elapsed = (currentTime - startTime) / 1000 -- Convert to seconds
            
            -- Warning at 75% of max duration
            if elapsed >= warningTime and not treatment.metadata.warningGiven then
                treatment.metadata.warningGiven = true
                lib.notify({
                    title = locale('cl_menu_medical_emergency'),
                    description = string.format(locale('cl_desc_fmt_tourniquet_warning'),
                        Config.BodyParts[bodyPart].label),
                    type = 'error',
                    duration = 10000
                })
            end
            
            -- Apply damage if over max duration
            if elapsed >= maxDuration then
                local ped = PlayerPedId()
                local currentHealth = GetEntityHealth(ped)
                local damageAmount = tourniquetConfig.damageAmount or Config.Tourniquet.damageAmount
                
                SetEntityHealth(ped, math.max(currentHealth - damageAmount, 1))

                lib.notify({
                    title = locale('cl_menu_tissue_damage'),
                    description = string.format(locale('cl_desc_fmt_tourniquet_damage'),
                        Config.BodyParts[bodyPart].label),
                    type = 'error',
                    duration = 5000
                })
            end
            
            Wait(damageInterval * 1000)
        end
        
        TourniquetTimers[bodyPart] = nil
    end)
end

--=========================================================
-- TOURNIQUET TREATMENT SYSTEM
--=========================================================
local function ApplyTourniquet(bodyPart, tourniquetType, appliedBy)
    local tourniquetConfig = Config.TourniquetTypes[tourniquetType]
    local bodyPart = string.upper(bodyPart)
    if not tourniquetConfig then
        print("[ERROR] Unknown tourniquet type: " .. tostring(tourniquetType))
        return false
    end
    
    local bodyPartConfig = Config.BodyParts[bodyPart]
    if not bodyPartConfig then
        print("[ERROR] Unknown body part: " .. tostring(bodyPart))
        return false
    end
    
    -- Check if tourniquet can be applied to this body part
    local canApply = false
    if Config.Tourniquet.applicableParts then
        for _, part in ipairs(Config.Tourniquet.applicableParts) do
            if part == bodyPart then
                canApply = true
                break
            end
        end
    end
    
    if not canApply then
        lib.notify({
            title = locale('cl_menu_treatment_error'),
            description = string.format(locale('cl_desc_fmt_cannot_apply_tourniquet'), bodyPartConfig.label),
            type = 'error',
            duration = 5000
        })
        return false
    end
    
    -- Check for existing tourniquet
    if ActiveTreatments[bodyPart] and ActiveTreatments[bodyPart].treatmentType == "tourniquet" then
        lib.notify({
            title = locale('cl_menu_treatment_error'),
            description = string.format(locale('cl_desc_fmt_tourniquet_already_applied'), bodyPartConfig.label),
            type = 'error',
            duration = 5000
        })
        return false
    end
    
    -- Get current wounds for bleeding check
    local wounds = PlayerWounds or {}
    local wound = wounds[bodyPart]
    local bleadingLevel = wound and tonumber(wound.bleedingLevel) or 0
    local painLevel = wound and tonumber(wound.painLevel) or 0
    -- Apply immediate bleeding control
    if wound and bleadingLevel > 0 then
        if math.random() <= tourniquetConfig.bleedingStopChance then
            bleadingLevel = 0
            TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', wounds)

            lib.notify({
                title = locale('cl_menu_emergency_treatment'),
                description = string.format(locale('cl_desc_fmt_tourniquet_stopped_bleeding'), bodyPartConfig.label),
                type = 'success',
                duration = 8000
            })
        else
            lib.notify({
                title = locale('cl_menu_emergency_treatment'),
                description = string.format(locale('cl_desc_fmt_tourniquet_bleeding_continues'), bodyPartConfig.label),
                type = 'warning',
                duration = 8000
            })
        end
    end
    
    -- Apply one-time healing if configured
    if tourniquetConfig.oneTimeHeal and tourniquetConfig.oneTimeHeal > 0 then
        local ped = PlayerPedId()
        local currentHealth = GetEntityHealth(ped)
        local newHealth = math.min(currentHealth + tourniquetConfig.oneTimeHeal, Config.MaxHealth)
        SetEntityHealth(ped, newHealth)
    end
    
    -- Increase pain due to tourniquet pressure
    if wound and tourniquetConfig.painIncrease then
        painLevel = math.min(painLevel + (tourniquetConfig.painIncrease / 10), 10)
        TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', wounds)
    end
    
    -- Track active tourniquet
    local duration = tourniquetConfig.maxDuration or Config.Tourniquet.maxDuration
    ActiveTreatments[bodyPart] = {
        treatmentType = "tourniquet",
        itemType = tourniquetType,
        appliedTime = GetGameTimer(),
        effectiveness = tourniquetConfig.effectiveness,
        duration = duration,
        appliedBy = appliedBy,
        metadata = {
            label = tourniquetConfig.label,
            maxDuration = duration,
            damageAmount = tourniquetConfig.damageAmount,
            warningGiven = false
        }
    }
    
    -- Start tourniquet damage timer
    StartTourniquetTimer(bodyPart, tourniquetType)
    
    -- Update server
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateTreatmentData', ActiveTreatments)

    lib.notify({
        title = locale('cl_menu_emergency_treatment'),
        description = string.format(locale('cl_desc_fmt_tourniquet_applied_warning'),
            tourniquetConfig.label,
            bodyPartConfig.label,
            math.floor(duration / 60)
        ),
        type = 'warning',
        duration = 10000
    })
    
    return true
end

--=========================================================
-- SIDE EFFECT SYSTEM
--=========================================================
local function ApplySideEffect(effect, duration)
    local ped = PlayerPedId()
    
    CreateThread(function()
        local endTime = GetGameTimer() + (duration * 1000)
        
        while GetGameTimer() < endTime do
            if effect == 'drowsiness' then
                SetPedMoveRateOverride(ped, 0.7)
            elseif effect == 'euphoria' then
                -- Could add visual effects or screen overlay
            elseif effect == 'intoxication' then
                SetPedMoveRateOverride(ped, 0.8)
                SetPedIsDrunk(ped, true)
            elseif effect == 'nausea' then
                -- Periodic screen shake
                if math.random() < 0.1 then
                    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.05)
                end
            elseif effect == 'rapid_heartbeat' then
                -- Could affect stamina regeneration
            elseif effect == 'anxiety' then
                -- Could affect accuracy or fine motor control
            elseif effect == 'tremors' then
                -- Periodic small shaking
                if math.random() < 0.05 then
                    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.03)
                end
            elseif effect == 'convulsions' then
                -- Severe shaking and loss of control
                SetPedToRagdoll(ped, 2000, 3000, 0, true, true, false)
                ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 0.15)
                Wait(5000) -- Longer wait for convulsions
            elseif effect == 'respiratory_depression' then
                -- Gradual health loss
                local currentHealth = GetEntityHealth(ped)
                SetEntityHealth(ped, math.max(currentHealth - 1, 1))
            end
            
            Wait(1000)
        end
        
        -- Clean up effects
        SetPedMoveRateOverride(ped, 1.0)
        SetPedIsDrunk(ped, false)
    end)
end

--=========================================================
-- MEDICINE TREATMENT SYSTEM  
--=========================================================
local function AdministreMedicine(medicineType, appliedBy)
    local medicineConfig = Config.MedicineTypes[medicineType]
    if not medicineConfig then
        print("[ERROR] Unknown medicine type: " .. tostring(medicineType))
        return false
    end
    
    -- Check for existing medicine effects
    if MedicineEffects[medicineType] and MedicineEffects[medicineType].endTime > GetGameTimer() then
        lib.notify({
            title = locale('cl_menu_medicine_error'),
            description = string.format(locale('cl_desc_fmt_already_under_effects'), medicineConfig.label),
            type = 'error',
            duration = 5000
        })
        return false
    end
    
    -- Apply immediate healing
    if medicineConfig.healAmount and medicineConfig.healAmount > 0 then
        local ped = PlayerPedId()
        local currentHealth = GetEntityHealth(ped)
        local newHealth = math.min(currentHealth + medicineConfig.healAmount, Config.MaxHealth)
        SetEntityHealth(ped, newHealth)
    end
    
    -- Track medicine effects
    local endTime = GetGameTimer() + (medicineConfig.duration * 1000)
    MedicineEffects[medicineType] = {
        startTime = GetGameTimer(),
        endTime = endTime,
        appliedBy = appliedBy,
        config = medicineConfig
    }
    
    -- Mark affected body parts as treated for pain management
    -- Medicine affects pain conditions across all wounded body parts
    if PlayerWounds then
        for bodyPart, woundData in pairs(PlayerWounds) do
            local painLevel = tonumber(woundData.painLevel) or 0
            if woundData and painLevel and painLevel > 0 then
                -- Add medicine treatment to the wound's treatments
                if not woundData.treatments then
                    woundData.treatments = {}
                end
                
                woundData.treatments[medicineType] = {
                    treatmentType = "medicine",
                    medicineType = medicineType,
                    appliedTime = GetGameTimer(),
                    appliedBy = appliedBy,
                    duration = medicineConfig.duration * 1000,
                    effectiveness = medicineConfig.effectiveness or 80,
                    painReliefLevel = medicineConfig.painReliefLevel or 3, -- How much pain it reduces
                    status = "active"
                }
                
                if Config.Debug then
                    print(string.format("^2[MEDICINE] Applied %s to %s for pain relief^7", medicineType, bodyPart))
                end
            end
        end
    end
    
    -- Apply side effects
    if medicineConfig.sideEffects then
        for _, effect in ipairs(medicineConfig.sideEffects) do
            ApplySideEffect(effect, medicineConfig.duration)
        end
    end
    
    -- Check for addiction risk
    if medicineConfig.addictionRisk and medicineConfig.addictionRisk > 0 then
        if math.random(100) <= medicineConfig.addictionRisk then
            -- TODO: Implement addiction system
            lib.notify({
                title = locale('cl_menu_medical_warning'),
                description = string.format(locale('cl_desc_fmt_developing_dependency'), medicineConfig.label),
                type = 'warning',
                duration = 8000
            })
        end
    end
    
    lib.notify({
        title = locale('cl_menu_medicine_administered'),
        description = string.format(locale('cl_desc_fmt_medicine_administered'),
            medicineConfig.label,
            math.floor(medicineConfig.duration / 60)
        ),
        type = 'success',
        duration = 8000
    })
    
    -- Start effect timer
    CreateThread(function()
        Wait(medicineConfig.duration * 1000)
        MedicineEffects[medicineType] = nil
        
        -- Remove medicine treatment markings from wounds when effects wear off
        if PlayerWounds then
            for bodyPart, woundData in pairs(PlayerWounds) do
                if woundData and woundData.treatments and woundData.treatments[medicineType] then
                    woundData.treatments[medicineType].status = "expired"
                    if Config.Debug then
                        print(string.format("^3[MEDICINE] %s effects expired on %s^7", medicineType, bodyPart))
                    end
                end
            end
        end
        
        lib.notify({
            title = locale('cl_menu_medicine_effects'),
            description = string.format(locale('cl_desc_fmt_effects_worn_off'), medicineConfig.label),
            type = 'inform',
            duration = 5000
        })
    end)
    
    return true
end

--=========================================================
-- INJECTION TREATMENT SYSTEM
--=========================================================
local function GiveInjection(injectionType, appliedBy)
    local injectionConfig = Config.InjectionTypes[injectionType]
    if not injectionConfig then
        print("[ERROR] Unknown injection type: " .. tostring(injectionType))
        return false
    end
    
    -- Check for existing injection effects
    if InjectionEffects[injectionType] and InjectionEffects[injectionType].endTime > GetGameTimer() then
        lib.notify({
            title = locale('cl_menu_injection_error'),
            description = string.format(locale('cl_desc_fmt_still_under_effects'), injectionConfig.label),
            type = 'error',
            duration = 5000
        })
        return false
    end
    
    -- Roll for overdose risk
    if injectionConfig.overdoseRisk and injectionConfig.overdoseRisk > 0 then
        if math.random(100) <= injectionConfig.overdoseRisk then
            -- Overdose occurred
            local ped = PlayerPedId()
            local currentHealth = GetEntityHealth(ped)
            local overdoseDamage = injectionConfig.healAmount or 20 -- Reverse healing as damage
            
            SetEntityHealth(ped, math.max(currentHealth - overdoseDamage, 1))

            lib.notify({
                title = locale('cl_menu_medical_emergency'),
                description = string.format(locale('cl_desc_fmt_overdose_warning'), injectionConfig.label),
                type = 'error',
                duration = 15000
            })
            
            -- Apply severe side effects
            ApplySideEffect('convulsions', 30)
            ApplySideEffect('respiratory_depression', 60)
            
            return false
        end
    end
    
    -- Apply immediate healing
    if injectionConfig.healAmount and injectionConfig.healAmount > 0 then
        local ped = PlayerPedId()
        local currentHealth = GetEntityHealth(ped)
        local newHealth = math.min(currentHealth + injectionConfig.healAmount, Config.MaxHealth)
        SetEntityHealth(ped, newHealth)
    end
    
    -- Track injection effects
    local endTime = GetGameTimer() + (injectionConfig.duration * 1000)
    InjectionEffects[injectionType] = {
        startTime = GetGameTimer(),
        endTime = endTime,
        appliedBy = appliedBy,
        config = injectionConfig
    }
    
    -- Apply side effects
    if injectionConfig.sideEffects then
        for _, effect in ipairs(injectionConfig.sideEffects) do
            ApplySideEffect(effect, injectionConfig.duration)
        end
    end
    
    lib.notify({
        title = locale('cl_menu_injection_administered'),
        description = string.format(locale('cl_desc_fmt_injection_administered'),
            injectionConfig.label,
            math.floor(injectionConfig.duration / 60)
        ),
        type = 'success',
        duration = 8000
    })
    
    -- Start effect timer
    CreateThread(function()
        Wait(injectionConfig.duration * 1000)
        InjectionEffects[injectionType] = nil
        
        lib.notify({
            title = locale('cl_menu_injection_effects'),
            description = string.format(locale('cl_desc_fmt_effects_worn_off'), injectionConfig.label),
            type = 'inform',
            duration = 5000
        })
    end)
    
    return true
end

--=========================================================
-- TREATMENT REMOVAL SYSTEM
--=========================================================
function RemoveTreatment(bodyPart, treatmentType)
    local treatment = ActiveTreatments[bodyPart]
    
    if not treatment or treatment.treatmentType ~= treatmentType then
        return false
    end
    
    if treatmentType == "bandage" then
        RemoveBandage(bodyPart)
    elseif treatmentType == "tourniquet" then
        if TourniquetTimers[bodyPart] then
            TourniquetTimers[bodyPart] = nil
        end
        
        lib.notify({
            title = locale('cl_menu_treatment_removal'),
            description = string.format(locale('cl_desc_fmt_tourniquet_removed'),
                Config.BodyParts[bodyPart] and Config.BodyParts[bodyPart].label or bodyPart),
            type = 'success',
            duration = 5000
        })
    end
    
    ActiveTreatments[bodyPart] = nil
    
    -- Update server with treatment data (for database and NUI)
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateTreatmentData', ActiveTreatments)
    
    -- Trigger specific removal event for NUI/medic interfaces
    TriggerServerEvent('QC-AdvancedMedic:server:TreatmentRemoved', bodyPart, treatmentType, treatment)
    
    return true
end

--=========================================================
-- EXPORTS FOR OTHER MODULES
--=========================================================
exports('ApplyBandage', function(bodyPart, bandageType, appliedBy)
    return ApplyBandage(bodyPart, bandageType, appliedBy or GetPlayerServerId(PlayerId()))
end)

exports('ApplyTourniquet', function(bodyPart, tourniquetType, appliedBy)
    return ApplyTourniquet(bodyPart, tourniquetType, appliedBy or GetPlayerServerId(PlayerId()))
end)

exports('AdministreMedicine', function(medicineType, appliedBy)
    return AdministreMedicine(medicineType, appliedBy or GetPlayerServerId(PlayerId()))
end)

exports('GiveInjection', function(injectionType, appliedBy)
    return GiveInjection(injectionType, appliedBy or GetPlayerServerId(PlayerId()))
end)

exports('RemoveTreatment', function(bodyPart, treatmentType)
    return RemoveTreatment(bodyPart, treatmentType)
end)


--=========================================================
-- NETWORK EVENTS
--=========================================================
RegisterNetEvent('QC-AdvancedMedic:client:ApplyBandage')
AddEventHandler('QC-AdvancedMedic:client:ApplyBandage', function(bodyPart, bandageType, appliedBy)
    ApplyBandage(bodyPart, bandageType, appliedBy)

end)

RegisterNetEvent('QC-AdvancedMedic:client:ApplyTourniquet')
AddEventHandler('QC-AdvancedMedic:client:ApplyTourniquet', function(bodyPart, tourniquetType, appliedBy)
    ApplyTourniquet(bodyPart, tourniquetType, appliedBy)
end)

RegisterNetEvent('QC-AdvancedMedic:client:AdministreMedicine')
AddEventHandler('QC-AdvancedMedic:client:AdministreMedicine', function(medicineType, appliedBy)
    AdministreMedicine(medicineType, appliedBy)
end)

RegisterNetEvent('QC-AdvancedMedic:client:ApplyMedicine')
AddEventHandler('QC-AdvancedMedic:client:ApplyMedicine', function(medicineType, appliedBy)
    AdministreMedicine(medicineType, appliedBy)
end)

RegisterNetEvent('QC-AdvancedMedic:client:GiveInjection')
AddEventHandler('QC-AdvancedMedic:client:GiveInjection', function(injectionType, appliedBy)
    GiveInjection(injectionType, appliedBy)
end)

RegisterNetEvent('QC-AdvancedMedic:client:LoadTreatments')
AddEventHandler('QC-AdvancedMedic:client:LoadTreatments', function(treatmentData)
    if treatmentData and type(treatmentData) == 'table' then
        -- Load active treatments from server data
        ActiveTreatments = {}
        
        for bodyPart, treatment in pairs(treatmentData) do
            if treatment and type(treatment) == 'table' then
                -- Check if treatment is active
                if treatment.isActive then
                    -- Convert expiration_time from MySQL datetime to game timer if it exists
                    local clientExpirationTime = nil
                    if treatment.expirationTime then
                        -- For now, we'll estimate based on current time + remaining duration
                        -- This is approximate since we don't have exact game timer sync
                        local bandageConfig = Config.BandageTypes[treatment.itemType]
                        if bandageConfig then
                            clientExpirationTime = GetGameTimer() + (bandageConfig.decayRate * 60 * 1000)
                        end
                    end
                    
                    ActiveTreatments[bodyPart] = {
                        treatmentType = treatment.treatmentType,
                        itemType = treatment.itemType,
                        appliedTime = GetGameTimer(), -- Reset to current time for simplicity
                        expirationTime = clientExpirationTime,
                        appliedBy = treatment.appliedBy,
                        originalPainLevel = treatment.originalPainLevel,
                        originalBleedingLevel = treatment.originalBleedingLevel,
                        painReduction = treatment.painReduction,
                        bleedingReduction = treatment.bleedingReduction,
                        isActive = true,
                        metadata = treatment.metadata or {}
                    }
                end
            end
        end
        
        if Config.TreatmentSystem and Config.TreatmentSystem.debugging and Config.TreatmentSystem.debugging.enabled then
            local treatmentCount = 0
            for bodyPart, treatment in pairs(ActiveTreatments) do
                treatmentCount = treatmentCount + 1
                print(string.format("^2[LOAD] %s: %s (%d%%)^7", 
                    bodyPart, treatment.treatmentType, treatment.effectiveness))
            end
            print(string.format("^2[TREATMENTS] Loaded %d active^7", treatmentCount))
        end
    end
end)

--=========================================================
-- BANDAGE SYSTEM - TIME-BASED EXPIRATION
--=========================================================
-- The bandage system now uses simple time-based expiration with 50% return
-- handled in the unified medical progression system in wound_system.lua
-- No effectiveness decay or gradual healing - just immediate effect + expiration

RegisterNetEvent('QC-AdvancedMedic:client:RemoveTreatment')
AddEventHandler('QC-AdvancedMedic:client:RemoveTreatment', function(bodyPart, treatmentType)
    RemoveTreatment(bodyPart, treatmentType)
end)

RegisterNetEvent('QC-AdvancedMedic:client:SyncTreatmentData')
AddEventHandler('QC-AdvancedMedic:client:SyncTreatmentData', function(treatmentData)
    ActiveTreatments = treatmentData or {}
end)

---------------------------------------------------------------------
-- Self-use tourniquet and injection events
---------------------------------------------------------------------
RegisterNetEvent('QC-AdvancedMedic:client:usetourniquet')
AddEventHandler('QC-AdvancedMedic:client:usetourniquet', function(tourniquetType)
    local PlayerData = RSGCore.Functions.GetPlayerData()

    if PlayerData.metadata['isdead'] or PlayerData.metadata['ishandcuffed'] then
        lib.notify({ title = locale('cl_error'), description = locale('cl_error_c'), type = 'error', duration = 5000 })
        return
    end

    -- Check for wounds
    local wounds = PlayerWounds or {}
    if not next(wounds) then
        lib.notify({
            title = locale('cl_error'),
            description = locale('treatment_no_wounds_tourniquet'),
            type = 'error',
            duration = 5000
        })
        return
    end

    -- Find most severe bleeding wound
    local targetBodyPart = nil
    local highestBleeding = 0

    for bodyPart, wound in pairs(wounds) do
        if wound.bleedingLevel and wound.bleedingLevel > highestBleeding then
            highestBleeding = wound.bleedingLevel
            targetBodyPart = bodyPart
        end
    end

    if not targetBodyPart then
        lib.notify({
            title = locale('cl_error'),
            description = locale('treatment_no_bleeding_tourniquet'),
            type = 'error',
            duration = 5000
        })
        return
    end

    -- Apply tourniquet
    local tourniquetConfig = Config.TourniquetTypes[tourniquetType]
    if not tourniquetConfig then
        lib.notify({ title = locale('cl_error'), description = locale('treatment_tourniquet_invalid'), type = 'error', duration = 5000 })
        return
    end

    ApplyTourniquet(targetBodyPart, tourniquetType, GetPlayerServerId(PlayerId()))

    -- Remove item on server
    TriggerServerEvent('QC-AdvancedMedic:server:removeitem', tourniquetConfig.itemName, 1)
end)

RegisterNetEvent('QC-AdvancedMedic:client:useinjection')
AddEventHandler('QC-AdvancedMedic:client:useinjection', function(injectionType)
    local PlayerData = RSGCore.Functions.GetPlayerData()

    if PlayerData.metadata['isdead'] or PlayerData.metadata['ishandcuffed'] then
        lib.notify({ title = locale('cl_error'), description = locale('cl_error_c'), type = 'error', duration = 5000 })
        return
    end

    -- Apply injection
    local injectionConfig = Config.InjectionTypes[injectionType]
    if not injectionConfig then
        lib.notify({ title = locale('cl_error'), description = locale('treatment_injection_invalid'), type = 'error', duration = 5000 })
        return
    end

    GiveInjection(injectionType, GetPlayerServerId(PlayerId()))

    -- Remove item on server
    TriggerServerEvent('QC-AdvancedMedic:server:removeitem', injectionConfig.itemName, 1)
end)

-- Functions are now globally accessible - no initialization needed