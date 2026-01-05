--=========================================================
-- QC-ADVANCED MEDIC - USEABLE ITEMS
--=========================================================
-- Handles item usage from inventory (bandages, etc.)
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
local isBusy = false
local targetBodyPartOverride = nil

--=========================================================
-- BANDAGE USAGE
--=========================================================

RegisterNetEvent('QC-AdvancedMedic:client:usebandage', function(bandageType)
    if isBusy then return end

    -- Default to cotton if no type specified
    bandageType = bandageType or 'cotton'

    -- Get bandage config
    local bandageConfig = Config.BandageTypes[bandageType]
    if not bandageConfig then
        lib.notify({
            title = locale('cl_menu_configuration_error'),
            description = string.format(locale('cl_desc_fmt_unknown_bandage_type'), bandageType),
            type = 'error',
            duration = 5000
        })
        return
    end

    local itemName = bandageConfig.itemName or bandageType
    local hasItem = RSGCore.Functions.HasItem(itemName, 1)
    local PlayerData = RSGCore.Functions.GetPlayerData()

    if PlayerData.metadata['isdead'] or PlayerData.metadata['ishandcuffed'] then
        lib.notify({
            title = locale('cl_error'),
            description = locale('cl_error_c'),
            type = 'error',
            duration = 5000
        })
        return
    end

    if not hasItem then
        lib.notify({
            title = locale('cl_error'),
            description = string.format(locale('cl_desc_fmt_no_item_available'), bandageConfig.label),
            type = 'error',
            duration = 5000
        })
        return
    end

    -- Check if player has any wounds to treat
    local wounds = exports['QC-AdvancedMedic']:GetMedicalState('wounds') or {}
    if not next(wounds) then
        lib.notify({
            title = locale('cl_error'),
            description = locale('cl_desc_no_wounds_bandaging'),
            type = 'error',
            duration = 5000
        })
        return
    end

    -- Find target body part
    local targetBodyPart = nil

    if targetBodyPartOverride then
        -- Command specified exact body part
        if wounds[targetBodyPartOverride] then
            targetBodyPart = targetBodyPartOverride
        else
            lib.notify({
                title = locale('cl_menu_treatment_error'),
                description = string.format(locale('cl_desc_fmt_no_wound_detected'),
                    Config.BodyParts[targetBodyPartOverride] and Config.BodyParts[targetBodyPartOverride].label or targetBodyPartOverride),
                type = 'error',
                duration = 5000
            })
            targetBodyPartOverride = nil
            return
        end
        targetBodyPartOverride = nil
    else
        -- Find most severe wound (prioritize bleeding > pain)
        local highestSeverity = 0

        for bodyPart, wound in pairs(wounds) do
            local severity = (wound.bleedingLevel * 2) + wound.painLevel
            if severity > highestSeverity then
                highestSeverity = severity
                targetBodyPart = bodyPart
            end
        end

        if not targetBodyPart then
            lib.notify({
                title = locale('cl_error'),
                description = locale('cl_desc_no_suitable_wound'),
                type = 'error',
                duration = 5000
            })
            return
        end
    end

    -- Check if body part already has a bandage
    local treatments = exports['QC-AdvancedMedic']:GetMedicalState('treatments') or {}
    if treatments[targetBodyPart] and treatments[targetBodyPart].treatmentType == "bandage" then
        lib.notify({
            title = locale('cl_menu_treatment_error'),
            description = string.format(locale('cl_desc_fmt_bandage_already_applied'),
                Config.BodyParts[targetBodyPart] and Config.BodyParts[targetBodyPart].label or targetBodyPart),
            type = 'error',
            duration = 5000
        })
        return
    end

    -- Apply bandage
    isBusy = true
    LocalPlayer.state:set('inv_busy', true, true)
    SetCurrentPedWeapon(cache.ped, GetHashKey('weapon_unarmed'))

    lib.progressBar({
        duration = Config.BandageTime,
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disableControl = true,
        disable = {
            move = true,
            mouse = true,
        },
        anim = {
            dict = 'mini_games@story@mob4@heal_jules@bandage@arthur',
            clip = 'bandage_fast',
            flag = 1,
        },
        label = string.format("Applying %s...", bandageConfig.label),
    })

    -- Apply bandage using core medical system
    local success = exports['QC-AdvancedMedic']:ApplyBandage(targetBodyPart, bandageType, GetPlayerServerId(PlayerId()))

    if success then
        TriggerServerEvent('QC-AdvancedMedic:server:removeitem', itemName, 1)
    else
        lib.notify({
            title = locale('cl_menu_treatment_failed'),
            description = locale('cl_desc_bandage_failed'),
            type = 'error',
            duration = 5000
        })
    end

    LocalPlayer.state:set('inv_busy', false, true)
    isBusy = false
end)

--=========================================================
-- SELF-TREATMENT CHECK
--=========================================================

RegisterNetEvent('QC-AdvancedMedic:client:CheckForSelfTreatment')
AddEventHandler('QC-AdvancedMedic:client:CheckForSelfTreatment', function(treatmentType, itemType)
    if treatmentType == "bandage" then
        TriggerEvent('QC-AdvancedMedic:client:usebandage', itemType)
    elseif treatmentType == "tourniquet" then
        -- Handled by core_medical.lua
        exports['QC-AdvancedMedic']:ApplyTourniquet(nil, itemType, GetPlayerServerId(PlayerId()))
    elseif treatmentType == "medicine" then
        -- Handled by core_medical.lua
        exports['QC-AdvancedMedic']:AdministreMedicine(itemType, GetPlayerServerId(PlayerId()))
    elseif treatmentType == "injection" then
        -- Handled by core_medical.lua
        exports['QC-AdvancedMedic']:GiveInjection(itemType, GetPlayerServerId(PlayerId()))
    end
end)

--=========================================================
-- EXPORTS
--=========================================================

exports('SetTargetBodyPartOverride', function(bodyPart)
    targetBodyPartOverride = bodyPart
end)
