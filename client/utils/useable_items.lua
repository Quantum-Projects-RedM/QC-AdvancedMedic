--=========================================================
-- QC-ADVANCED MEDIC - USEABLE ITEMS
--=========================================================
-- Handles item usage from inventory (bandages, etc.)
-- Version: 0.4.0 Simplified (global bleeding, no body parts)
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
QCMed = QCMed or {}
local isBusy = false

--=========================================================
-- BANDAGE HELPER FUNCTIONS
--=========================================================

-- Validate bandage usage (consolidated validation)
local function ValidateBandageUsage(bandageType)
    local bandageConfig = Config.BandageTypes[bandageType or 'cotton']
    if not bandageConfig then
        return false, string.format(locale('cl_desc_fmt_unknown_bandage_type'), bandageType)
    end

    if isBusy then
        return false, locale('cl_error_c')
    end

    local PlayerData = RSGCore.Functions.GetPlayerData()
    if PlayerData.metadata['isdead'] or PlayerData.metadata['ishandcuffed'] then
        return false, locale('cl_error_c')
    end

    local itemName = bandageConfig.itemName or bandageType
    if not RSGCore.Functions.HasItem(itemName, 1) then
        return false, string.format(locale('cl_desc_fmt_no_item_available'), bandageConfig.label)
    end

    -- Check for wounds (global check - no body parts)
    if not QCMed.IsWounded() then
        return false, locale('cl_desc_no_wounds_bandaging')
    end

    -- Check if a bandage is already active (must wait for it to expire)
    local state = QCMed.GetMedicalState()
    if state and state.activeBandage then
        return false, "You already have an active bandage. Wait for it to expire before applying a new one."
    end

    return true, bandageConfig, itemName
end

-- Apply bandage with animation and progress bar
local function ApplyBandageWithAnimation(bandageType, bandageConfig, itemName)
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

    -- Apply bandage using core medical system (no body part needed)
    local success = QCMed.ApplyBandage(bandageType, GetPlayerServerId(PlayerId()))

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
    bandageType = bandageType or 'cotton'

    local valid, configOrError, itemName = ValidateBandageUsage(bandageType)
    if not valid then
        lib.notify({
            title = locale('cl_error'),
            description = configOrError,
            type = 'error',
            duration = 5000
        })
        return
    end

    local bandageConfig = configOrError

    -- Apply bandage with animation (no body part selection needed)
    ApplyBandageWithAnimation(bandageType, bandageConfig, itemName)
end)

--=========================================================
-- TOURNIQUET USAGE
--=========================================================

RegisterNetEvent('QC-AdvancedMedic:client:usetourniquet', function(tourniquetType)
    tourniquetType = tourniquetType or 'rope'

    local tourniquetConfig = Config.TourniquetTypes[tourniquetType]
    if not tourniquetConfig then
        lib.notify({
            title = locale('cl_error'),
            description = string.format("Unknown tourniquet type: %s", tourniquetType),
            type = 'error',
            duration = 5000
        })
        return
    end

    if isBusy then
        lib.notify({ title = locale('cl_error'), description = locale('cl_error_c'), type = 'error', duration = 5000 })
        return
    end

    local PlayerData = RSGCore.Functions.GetPlayerData()
    if PlayerData.metadata['isdead'] or PlayerData.metadata['ishandcuffed'] then
        lib.notify({ title = locale('cl_error'), description = locale('cl_error_c'), type = 'error', duration = 5000 })
        return
    end

    local itemName = tourniquetConfig.itemName or tourniquetType
    if not RSGCore.Functions.HasItem(itemName, 1) then
        lib.notify({
            title = locale('cl_error'),
            description = string.format(locale('cl_desc_fmt_no_item_available'), tourniquetConfig.label),
            type = 'error',
            duration = 5000
        })
        return
    end

    isBusy = true
    LocalPlayer.state:set('inv_busy', true, true)
    SetCurrentPedWeapon(cache.ped, GetHashKey('weapon_unarmed'))

    lib.progressBar({
        duration = Config.BandageTime,
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disableControl = true,
        disable = { move = true, mouse = true },
        anim = {
            dict = 'mini_games@story@mob4@heal_jules@bandage@arthur',
            clip = 'bandage_fast',
            flag = 1,
        },
        label = string.format("Applying %s...", tourniquetConfig.label),
    })

    local success = QCMed.ApplyTourniquet(tourniquetType, GetPlayerServerId(PlayerId()))

    if success then
        TriggerServerEvent('QC-AdvancedMedic:server:removeitem', itemName, 1)
    else
        lib.notify({
            title = locale('cl_menu_treatment_failed'),
            description = locale('cl_desc_tourniquet_failed'),
            type = 'error',
            duration = 5000
        })
    end

    LocalPlayer.state:set('inv_busy', false, true)
    isBusy = false
end)

--=========================================================
-- INJECTION USAGE
--=========================================================

RegisterNetEvent('QC-AdvancedMedic:client:useinjection', function(injectionType)
    injectionType = injectionType or 'saline'

    local injectionConfig = Config.InjectionTypes[injectionType]
    if not injectionConfig then
        lib.notify({
            title = locale('cl_error'),
            description = string.format("Unknown injection type: %s", injectionType),
            type = 'error',
            duration = 5000
        })
        return
    end

    if isBusy then
        lib.notify({ title = locale('cl_error'), description = locale('cl_error_c'), type = 'error', duration = 5000 })
        return
    end

    local PlayerData = RSGCore.Functions.GetPlayerData()
    if PlayerData.metadata['isdead'] or PlayerData.metadata['ishandcuffed'] then
        lib.notify({ title = locale('cl_error'), description = locale('cl_error_c'), type = 'error', duration = 5000 })
        return
    end

    local itemName = injectionConfig.itemName or injectionType
    if not RSGCore.Functions.HasItem(itemName, 1) then
        lib.notify({
            title = locale('cl_error'),
            description = string.format(locale('cl_desc_fmt_no_item_available'), injectionConfig.label),
            type = 'error',
            duration = 5000
        })
        return
    end

    isBusy = true
    LocalPlayer.state:set('inv_busy', true, true)
    SetCurrentPedWeapon(cache.ped, GetHashKey('weapon_unarmed'))

    lib.progressBar({
        duration = Config.BandageTime,
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disableControl = true,
        disable = { move = true, mouse = true },
        anim = {
            dict = 'mini_games@story@mob4@heal_jules@bandage@arthur',
            clip = 'bandage_fast',
            flag = 1,
        },
        label = string.format("Administering %s...", injectionConfig.label),
    })

    QCMed.GiveInjection(injectionType, GetPlayerServerId(PlayerId()))
    TriggerServerEvent('QC-AdvancedMedic:server:removeitem', itemName, 1)

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
        local success = QCMed.ApplyTourniquet(itemType, GetPlayerServerId(PlayerId()))

        if not success then
            lib.notify({
                title = locale('cl_menu_treatment_failed'),
                description = locale('cl_desc_tourniquet_failed'),
                type = 'error',
                duration = 5000
            })
        end
    elseif treatmentType == "medicine" then
        QCMed.AdministreMedicine(itemType, GetPlayerServerId(PlayerId()))
    elseif treatmentType == "injection" then
        QCMed.GiveInjection(itemType, GetPlayerServerId(PlayerId()))
    end
end)
