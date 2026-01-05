--=========================================================
-- QC-ADVANCED MEDIC - USEABLE ITEMS
--=========================================================
-- Handles item usage from inventory (bandages, etc.)
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
local isBusy = false
local targetBodyPartOverride = nil

--=========================================================
-- BANDAGE HELPER FUNCTIONS
--=========================================================

-- Validate bandage usage (consolidated validation)
local function ValidateBandageUsage(bandageType)
    -- Get bandage configuration
    local bandageConfig = Config.BandageTypes[bandageType or 'cotton']
    if not bandageConfig then
        return false, locale('cl_desc_fmt_unknown_bandage_type'), bandageType
    end

    -- Check if busy
    if isBusy then
        return false, locale('cl_error_c')
    end

    -- Check player state (dead/handcuffed)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    if PlayerData.metadata['isdead'] or PlayerData.metadata['ishandcuffed'] then
        return false, locale('cl_error_c')
    end

    -- Check item possession
    local itemName = bandageConfig.itemName or bandageType
    if not RSGCore.Functions.HasItem(itemName, 1) then
        return false, string.format(locale('cl_desc_fmt_no_item_available'), bandageConfig.label)
    end

    -- Check for wounds
    local wounds = exports['QC-AdvancedMedic']:GetMedicalState('wounds') or {}
    if not next(wounds) then
        return false, locale('cl_desc_no_wounds_bandaging')
    end

    return true, bandageConfig, itemName
end

-- Select body part for bandage application
local function SelectBodyPartForBandage(override)
    local wounds = exports['QC-AdvancedMedic']:GetMedicalState('wounds')

    if override then
        -- Command specified exact body part
        if wounds[override] then
            return override
        else
            lib.notify({
                title = locale('cl_menu_treatment_error'),
                description = string.format(
                    locale('cl_desc_fmt_no_wound_detected'),
                    Config.BodyParts[override] and Config.BodyParts[override].label or override
                ),
                type = 'error',
                duration = 5000
            })
            return nil
        end
    end

    -- Auto-selection: Find most severe wound (prioritize bleeding > pain)
    local highestSeverity = 0
    local targetBodyPart = nil

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
        return nil
    end

    return targetBodyPart
end

-- Check if body part already has active bandage
local function HasActiveBandage(bodyPart)
    local treatments = exports['QC-AdvancedMedic']:GetMedicalState('treatments') or {}
    return treatments[bodyPart] and treatments[bodyPart].treatmentType == "bandage"
end

-- Apply bandage with animation and progress bar
local function ApplyBandageWithAnimation(bodyPart, bandageType, bandageConfig, itemName)
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
    local success = exports['QC-AdvancedMedic']:ApplyBandage(bodyPart, bandageType, GetPlayerServerId(PlayerId()))

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
end

--=========================================================
-- BANDAGE USAGE
--=========================================================

RegisterNetEvent('QC-AdvancedMedic:client:usebandage', function(bandageType)
    -- Default to cotton if no type specified
    bandageType = bandageType or 'cotton'

    -- Validate bandage usage (consolidated validation)
    local valid, configOrError, itemName = ValidateBandageUsage(bandageType)
    if not valid then
        lib.notify({
            title = locale('cl_error'),
            description = configOrError, -- Error message
            type = 'error',
            duration = 5000
        })
        return
    end

    local bandageConfig = configOrError

    -- Select body part (auto-selection or override)
    local targetBodyPart = SelectBodyPartForBandage(targetBodyPartOverride)
    targetBodyPartOverride = nil -- Clear override after use

    if not targetBodyPart then
        return -- Error notification already shown by SelectBodyPartForBandage
    end

    -- Check for duplicate bandage
    if HasActiveBandage(targetBodyPart) then
        lib.notify({
            title = locale('cl_menu_treatment_error'),
            description = string.format(
                locale('cl_desc_fmt_bandage_already_applied'),
                Config.BodyParts[targetBodyPart] and Config.BodyParts[targetBodyPart].label or targetBodyPart
            ),
            type = 'error',
            duration = 5000
        })
        return
    end

    -- Apply bandage with animation
    ApplyBandageWithAnimation(targetBodyPart, bandageType, bandageConfig, itemName)
end)

--=========================================================
-- SELF-TREATMENT CHECK
--=========================================================

RegisterNetEvent('QC-AdvancedMedic:client:CheckForSelfTreatment')
AddEventHandler('QC-AdvancedMedic:client:CheckForSelfTreatment', function(treatmentType, itemType)
    if treatmentType == "bandage" then
        TriggerEvent('QC-AdvancedMedic:client:usebandage', itemType)
    elseif treatmentType == "tourniquet" then
        -- Global tourniquet application (no body part needed)
        local success = exports['QC-AdvancedMedic']:ApplyTourniquet(itemType, GetPlayerServerId(PlayerId()))

        if not success then
            lib.notify({
                title = locale('cl_menu_treatment_failed'),
                description = locale('cl_desc_tourniquet_failed'),
                type = 'error',
                duration = 5000
            })
        end
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
