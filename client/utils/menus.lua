--=========================================================
-- QC-ADVANCED MEDIC - MENUS & SHOPS
--=========================================================
-- Handles duty management, medical supplies shop, pharmaceutical shop
-- All ox_lib context menus
-- Version: 0.4.0 Simplified (global bleeding, no body parts)
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
QCMed = QCMed or {}

--=========================================================
-- STATE VARIABLES
--=========================================================

local mediclocation = nil
local dutyStartTime = nil
local sessionTime = 0

--=========================================================
-- HELPER FUNCTIONS
--=========================================================

-- Check if player can access this location
local function CanAccessLocation(location)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local playerJob = PlayerData.job.name

    for _, locationData in pairs(Config.MedicJobLocations) do
        if locationData.prompt == location or locationData.name == location then
            return playerJob == locationData.job
        end
    end
    return false
end

-- Format time (seconds to HH:MM:SS)
local function FormatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Get session duty time
local function GetSessionDutyTime()
    if dutyStartTime then
        return GetGameTimer() - dutyStartTime
    end
    return sessionTime
end

--=========================================================
-- MAIN MEDIC MENU
--=========================================================

AddEventHandler('QC-AdvancedMedic:client:mainmenu', function(location, name)
    if not CanAccessLocation(location) then
        lib.notify({
            title = locale('cl_access_denied'),
            description = locale('cl_no_access_facility'),
            type = 'error',
            icon = 'fa-solid fa-kit-medical',
            iconAnimation = 'shake',
            duration = 7000
        })
        return
    end

    mediclocation = location

    local PlayerData = RSGCore.Functions.GetPlayerData()
    local job = PlayerData.job
    local grade = job.grade.level
    local isBoss = job.grade.isboss
    local isPharmacist = (grade >= 2)

    local menuOptions = {
        {
            title = locale('cl_duty'),
            icon = 'fa-solid fa-shield-heart',
            description = locale('cl_desc_duty_management'),
            event = 'QC-AdvancedMedic:client:OpenDutyMenu',
            arrow = true
        },
        {
            title = locale('cl_medical_storage'),
            icon = 'fa-solid fa-box-open',
            description = locale('cl_medical_storage_desc') or 'Access medical equipment storage',
            event = 'QC-AdvancedMedic:client:storage',
            arrow = true
        },
        {
            title = locale('cl_medical_supplies'),
            icon = 'fa-solid fa-pills',
            description = locale('cl_desc_purchase_supplies'),
            event = 'QC-AdvancedMedic:client:OpenMedicSupplies',
            arrow = true
        },
        {
            title = locale('cl_menu_start_medical_mission'),
            icon = 'fa-solid fa-briefcase-medical',
            event = 'QC-AdvancedMedic:client:startMission',
            arrow = true
        },
    }

    -- Pharmaceutical Supplies (Pharmacist and Boss only)
    if isPharmacist or isBoss then
        table.insert(menuOptions, {
            title = locale('cl_pharmaceutical_supplies') or 'Pharmaceutical Supplies',
            icon = 'fa-solid fa-flask',
            description = locale('cl_desc_experimental_medicine'),
            event = 'QC-AdvancedMedic:client:OpenPharmaceuticalShop',
            arrow = true
        })
    end

    -- Manage Employees (Boss only)
    if isBoss then
        table.insert(menuOptions, {
            title = locale('cl_employees'),
            icon = 'fa-solid fa-list',
            description = locale('cl_employees_b'),
            event = 'rsg-bossmenu:client:mainmenu',
            arrow = true
        })
    end

    lib.registerContext({
        id = "medic_mainmenu",
        title = name,
        options = menuOptions
    })
    lib.showContext("medic_mainmenu")
end)

-- Back button handler
AddEventHandler('QC-AdvancedMedic:client:medicmenu', function(data)
    if data and data.location then
        TriggerEvent('QC-AdvancedMedic:client:mainmenu', data.location, data.location)
    end
end)

--=========================================================
-- DUTY MANAGEMENT
--=========================================================

AddEventHandler('QC-AdvancedMedic:client:OpenDutyMenu', function()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local onDuty = PlayerData.job.onduty
    local sessionTimeMs = GetSessionDutyTime()
    local sessionTimeFormatted = FormatTime(math.floor(sessionTimeMs / 1000))

    local dutyStatusText = onDuty and "ON DUTY" or "OFF DUTY"

    lib.registerContext({
        id = "medic_duty_menu",
        title = locale('cl_menu_duty_management'),
        options = {
            {
                title = locale('cl_menu_current_status') .. dutyStatusText,
                icon = onDuty and 'fa-solid fa-user-check' or 'fa-solid fa-user-times',
                description = locale('cl_desc_current_duty_status'),
                readOnly = true
            },
            {
                title = locale('cl_menu_session_time') .. sessionTimeFormatted,
                icon = 'fa-solid fa-clock',
                description = locale('cl_desc_duty_time'),
                readOnly = true
            },
            {
                title = onDuty and "Go Off Duty" or "Go On Duty",
                icon = onDuty and 'fa-solid fa-sign-out-alt' or 'fa-solid fa-sign-in-alt',
                description = onDuty and "Clock out and go off duty" or "Clock in and go on duty",
                event = 'QC-AdvancedMedic:client:ToggleDutyStatus',
                arrow = true
            },
            {
                title = locale('cl_menu_back_main'),
                icon = 'fa-solid fa-arrow-left',
                description = locale('cl_desc_return_menu'),
                event = 'QC-AdvancedMedic:client:medicmenu',
                args = { location = mediclocation }
            }
        }
    })
    lib.showContext("medic_duty_menu")
end)

AddEventHandler('QC-AdvancedMedic:client:ToggleDutyStatus', function()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local wasOnDuty = PlayerData.job.onduty

    if wasOnDuty then
        -- Going off duty
        if dutyStartTime then
            sessionTime = sessionTime + (GetGameTimer() - dutyStartTime)
            dutyStartTime = nil
        end

        local totalSessionTimeSeconds = math.floor(sessionTime / 1000)
        TriggerServerEvent('QC-AdvancedMedic:server:ProcessDutyPay', totalSessionTimeSeconds)

        lib.notify({
            title = locale('cl_menu_clocked_out'),
            description = string.format(locale('cl_desc_fmt_session_time'), FormatTime(totalSessionTimeSeconds)),
            type = 'success',
            duration = 5000
        })

        sessionTime = 0
    else
        -- Going on duty
        dutyStartTime = GetGameTimer()
        TriggerServerEvent('QC-AdvancedMedic:server:StartDutyPayTimer')
        lib.notify({
            title = locale('cl_menu_clocked_in'),
            description = locale('cl_desc_now_on_duty'),
            type = 'success',
            duration = 5000
        })
    end

    TriggerServerEvent('RSGCore:ToggleDuty')
end)

--=========================================================
-- MEDICAL SUPPLIES SHOP
--=========================================================

AddEventHandler('QC-AdvancedMedic:client:OpenMedicSupplies', function()
    local suppliesOptions = {}

    -- Bandages
    for bandageType, config in pairs(Config.BandageTypes) do
        table.insert(suppliesOptions, {
            title = config.label .. " - $" .. (config.price or 25),
            description = config.description,
            icon = 'fa-solid fa-bandage',
            event = 'QC-AdvancedMedic:client:PurchasePharmaceutical',
            args = { type = 'bandage', item = config.itemName, price = config.price or 25, label = config.label }
        })
    end

    -- Tourniquets
    for tourniquetType, config in pairs(Config.TourniquetTypes or {}) do
        table.insert(suppliesOptions, {
            title = config.label .. " - $" .. (config.price or 30),
            description = config.description,
            icon = 'fa-solid fa-circle-notch',
            event = 'QC-AdvancedMedic:client:PurchasePharmaceutical',
            args = { type = 'tourniquet', item = config.itemName, price = config.price or 30, label = config.label }
        })
    end

    -- Back button
    table.insert(suppliesOptions, {
        title = locale('cl_menu_back_main'),
        icon = 'fa-solid fa-arrow-left',
        event = 'QC-AdvancedMedic:client:medicmenu',
        args = { location = mediclocation }
    })

    lib.registerContext({
        id = "medic_supplies_shop",
        title = locale('cl_menu_supplies_title'),
        options = suppliesOptions
    })
    lib.showContext("medic_supplies_shop")
end)

--=========================================================
-- PHARMACEUTICAL SHOP
--=========================================================

AddEventHandler('QC-AdvancedMedic:client:OpenPharmaceuticalShop', function()
    local pharmaceuticalOptions = {}

    -- Medicines
    for medicineType, config in pairs(Config.MedicineTypes or {}) do
        table.insert(pharmaceuticalOptions, {
            title = config.label .. " - $" .. (config.price or 50),
            description = config.description,
            icon = 'fa-solid fa-pills',
            event = 'QC-AdvancedMedic:client:PurchasePharmaceutical',
            args = { type = 'medicine', item = config.itemName, price = config.price or 50, label = config.label }
        })
    end

    -- Injections
    for injectionType, config in pairs(Config.InjectionTypes or {}) do
        table.insert(pharmaceuticalOptions, {
            title = config.label .. " - $" .. (config.price or 50),
            description = config.description,
            icon = 'fa-solid fa-syringe',
            event = 'QC-AdvancedMedic:client:PurchasePharmaceutical',
            args = { type = 'injection', item = config.itemName, price = config.price or 50, label = config.label }
        })
    end

    -- Back button
    table.insert(pharmaceuticalOptions, {
        title = locale('cl_menu_back_main'),
        icon = 'fa-solid fa-arrow-left',
        event = 'QC-AdvancedMedic:client:medicmenu',
        args = { location = mediclocation }
    })

    lib.registerContext({
        id = "pharmaceutical_shop",
        title = locale('cl_menu_pharma_title'),
        options = pharmaceuticalOptions
    })
    lib.showContext("pharmaceutical_shop")
end)

-- Purchase handler
AddEventHandler('QC-AdvancedMedic:client:PurchasePharmaceutical', function(data)
    local input = lib.inputDialog('Purchase ' .. data.label, {
        {type = 'number', label = 'Quantity', description = locale('cl_desc_quantity_purchase'), default = 1, min = 1, max = 10}
    })

    if input and input[1] then
        local quantity = tonumber(input[1])
        local totalCost = (data.price or 25) * quantity

        TriggerServerEvent('QC-AdvancedMedic:server:PurchasePharmaceutical', {
            item = data.item,
            quantity = quantity,
            price = data.price or 25,
            totalCost = totalCost,
            label = data.label,
            type = data.type
        })
    end
end)

--=========================================================
-- STORAGE ACCESS
--=========================================================

AddEventHandler('QC-AdvancedMedic:client:storage', function()
    TriggerServerEvent('QC-AdvancedMedic:server:openstash', mediclocation)
end)

--=========================================================
-- HEALTH STATUS (ACCESSIBLE TO ALL PLAYERS)
-- Simplified: Shows global bleeding + bandage progress
--=========================================================

RegisterNetEvent('QC-AdvancedMedic:client:ShowHealthStatus')
AddEventHandler('QC-AdvancedMedic:client:ShowHealthStatus', function()
    local medicalState = QCMed.GetMedicalState()
    local menuOptions = {}

    -- Header with overall health
    local currentHealth = GetEntityHealth(cache.ped)
    local maxHealth = GetEntityMaxHealth(cache.ped)
    local healthPercentage = math.floor((currentHealth / maxHealth) * 100)

    table.insert(menuOptions, {
        title = "Overall Health: " .. healthPercentage .. "%",
        icon = 'fa-solid fa-heart-pulse',
        description = string.format("Current: %d / Max: %d", currentHealth, maxHealth),
        readOnly = true
    })

    -- Global Bleeding Status
    if medicalState.bleedingLevel and medicalState.bleedingLevel > 0 then
        table.insert(menuOptions, {
            title = string.format("Bleeding: %.1f/10", medicalState.bleedingLevel),
            icon = 'fa-solid fa-droplet',
            description = medicalState.bleedingLevel >= 7 and "SEVERE - Seek immediate treatment!" or
                          medicalState.bleedingLevel >= 4 and "Moderate bleeding - Apply bandage" or
                          "Minor bleeding",
            readOnly = true
        })
    else
        table.insert(menuOptions, {
            title = "Bleeding: None",
            icon = 'fa-solid fa-droplet',
            description = "No active bleeding",
            readOnly = true
        })
    end

    -- Bandage Progress
    if medicalState.bandageChangesNeeded and medicalState.bandageChangesNeeded > 0 then
        local progress = string.format("%d/%d bandage changes",
            medicalState.bandageChangesApplied or 0, medicalState.bandageChangesNeeded)
        local isHealed = (medicalState.bandageChangesApplied or 0) >= medicalState.bandageChangesNeeded

        table.insert(menuOptions, {
            title = isHealed and "Wound: Fully Treated" or "Wound: Needs Treatment",
            icon = isHealed and 'fa-solid fa-check-circle' or 'fa-solid fa-band-aid',
            description = progress .. (medicalState.lastWoundSource and (" | Cause: " .. medicalState.lastWoundSource) or ""),
            readOnly = true
        })
    else
        table.insert(menuOptions, {
            title = "No Active Wounds",
            icon = 'fa-solid fa-check-circle',
            description = "No wounds requiring treatment",
            readOnly = true
        })
    end

    -- Active Bandage
    if medicalState.activeBandage then
        local bandage = medicalState.activeBandage
        local remainingMs = (bandage.expirationTime or 0) - GetGameTimer()
        local remainingMin = math.max(0, math.floor(remainingMs / 1000 / 60))
        local remainingSec = math.max(0, math.floor((remainingMs / 1000) % 60))

        table.insert(menuOptions, {
            title = string.format("Active Bandage: %s", bandage.config and bandage.config.label or bandage.type or "Unknown"),
            icon = 'fa-solid fa-bandage',
            description = string.format("%d:%02d remaining | Healing active", remainingMin, remainingSec),
            readOnly = true
        })
    end

    -- Global Infection Status
    local infectionData = QCMed.GetGlobalInfection()
    if infectionData and infectionData.level > 0 then
        local stageNames = {
            [0] = "None",
            [1] = "Mild",
            [2] = "Moderate",
            [3] = "Severe",
            [4] = "Critical"
        }

        table.insert(menuOptions, {
            title = "Infection: " .. (stageNames[infectionData.stage] or "Unknown"),
            icon = 'fa-solid fa-virus',
            description = string.format("Infection Level: %d%%", infectionData.level),
            readOnly = true
        })
    else
        table.insert(menuOptions, {
            title = "Infection: None",
            icon = 'fa-solid fa-shield-virus',
            description = "No active infection detected",
            readOnly = true
        })
    end

    -- Global Tourniquet Status
    if LocalPlayer.state.tourniquet and LocalPlayer.state.tourniquet > GetGameTimer() then
        local remainingTime = math.floor((LocalPlayer.state.tourniquet - GetGameTimer()) / 1000 / 60)
        table.insert(menuOptions, {
            title = "Tourniquet Active",
            icon = 'fa-solid fa-circle-notch',
            description = string.format("Stops all bleeding | %d minutes remaining", remainingTime),
            readOnly = true
        })
    end

    -- Active Fractures
    local fractures = QCMed.GetPlayerFractures()
    if fractures and next(fractures) then
        for bodyPart, fracture in pairs(fractures) do
            local bodyPartLabel = Config.BodyPartLabels[bodyPart] or bodyPart
            local description = string.format("%s | Severity: %d | Healing: %.0f%%",
                fracture.type or "Fracture",
                fracture.severity or 5,
                fracture.healingProgress or 0
            )

            table.insert(menuOptions, {
                title = bodyPartLabel .. " - Fractured",
                icon = 'fa-solid fa-bone',
                description = description,
                readOnly = true
            })
        end
    end

    lib.registerContext({
        id = "health_status_menu",
        title = "Medical Status",
        options = menuOptions
    })
    lib.showContext("health_status_menu")
end)

--=========================================================
-- JOB UPDATE HANDLER
--=========================================================

local lastJobName = nil

RegisterNetEvent('RSGCore:Client:OnJobUpdate')
AddEventHandler('RSGCore:Client:OnJobUpdate', function(JobInfo)
    -- Only reset duty time when the actual job changes, not on duty toggle
    if lastJobName and lastJobName ~= JobInfo.name then
        dutyStartTime = nil
        sessionTime = 0
    end
    lastJobName = JobInfo.name
end)
