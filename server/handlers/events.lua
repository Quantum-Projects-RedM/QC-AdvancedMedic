--=========================================================
-- QC-ADVANCED MEDIC - EVENT HANDLERS
--=========================================================
-- Server network event handlers for medical system
-- Extracted from medical_events.lua for better organization
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

--=========================================================
-- MEDICAL DATA PERSISTENCE
--=========================================================

-- Load all medical data from database when player spawns
RegisterNetEvent('QC-AdvancedMedic:server:LoadMedicalData')
AddEventHandler('QC-AdvancedMedic:server:LoadMedicalData', function()
    local src = source
    local Player, err = exports['QC-AdvancedMedic']:ValidatePlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Load medical data safely
    local wounds = {}
    local infections = {}
    local treatments = {}

    pcall(function()
        wounds = exports['QC-AdvancedMedic']:LoadWoundData(citizenid) or {}
    end)

    pcall(function()
        infections = exports['QC-AdvancedMedic']:LoadInfectionData(citizenid) or {}
    end)

    pcall(function()
        treatments = exports['QC-AdvancedMedic']:LoadTreatmentData(citizenid) or {}
    end)

    -- Send data to client
    if next(wounds) then
        TriggerClientEvent('QC-AdvancedMedic:client:LoadWounds', src, wounds)
    end

    if next(infections) then
        TriggerClientEvent('QC-AdvancedMedic:client:LoadInfections', src, infections)
    end

    if next(treatments) then
        TriggerClientEvent('QC-AdvancedMedic:client:LoadTreatments', src, treatments)
    end

    if Config.WoundSystem.debugging.enabled then
        local woundCount = 0
        for _ in pairs(wounds) do woundCount = woundCount + 1 end
        print(string.format("^2[EVENTS] Loaded %d wounds for player %d^7", woundCount, src))
    end
end)

-- Save medical data on disconnect
RegisterNetEvent('QC-AdvancedMedic:server:SaveMedicalDataOnDisconnect')
AddEventHandler('QC-AdvancedMedic:server:SaveMedicalDataOnDisconnect', function(woundData, treatmentData, infectionData)
    local src = source
    local Player, err = exports['QC-AdvancedMedic']:ValidatePlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Save all medical data
    pcall(function()
        if woundData then
            exports['QC-AdvancedMedic']:SaveWoundData(citizenid, woundData)
        end
        if treatmentData then
            exports['QC-AdvancedMedic']:SaveTreatmentData(citizenid, treatmentData)
        end
        if infectionData then
            exports['QC-AdvancedMedic']:SaveInfectionData(citizenid, infectionData)
        end
    end)

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[EVENTS] Saved medical data on disconnect for player %d^7", src))
    end
end)

--=========================================================
-- WOUND DATA EVENTS
--=========================================================

-- Update wound data (legacy non-callback version for compatibility)
RegisterNetEvent('QC-AdvancedMedic:server:UpdateWoundData')
AddEventHandler('QC-AdvancedMedic:server:UpdateWoundData', function(woundData)
    local src = source
    exports['QC-AdvancedMedic']:HandleWoundUpdate(src, woundData)
end)

-- Request wound data for another player (for medic inspection)
RegisterNetEvent('QC-AdvancedMedic:server:RequestWoundData')
AddEventHandler('QC-AdvancedMedic:server:RequestWoundData', function(targetPlayerId)
    local src = source

    -- Validate requesting player is medic
    local Medic, err = exports['QC-AdvancedMedic']:ValidateMedic(src)
    if not Medic then
        exports['QC-AdvancedMedic']:NotifyValidationError(src, err)
        return
    end

    -- Validate target player
    local Target, err2 = exports['QC-AdvancedMedic']:ValidatePlayer(targetPlayerId)
    if not Target then
        exports['QC-AdvancedMedic']:NotifyValidationError(src, err2)
        return
    end

    -- Load target's medical data
    local wounds = {}
    pcall(function()
        wounds = exports['QC-AdvancedMedic']:LoadWoundData(Target.PlayerData.citizenid) or {}
    end)

    -- Send to requesting medic
    TriggerClientEvent('QC-AdvancedMedic:client:ReceiveWoundData', src, targetPlayerId, wounds)
end)

--=========================================================
-- TREATMENT EVENTS
--=========================================================

-- Update treatment data (legacy non-callback version)
RegisterNetEvent('QC-AdvancedMedic:server:UpdateTreatmentData')
AddEventHandler('QC-AdvancedMedic:server:UpdateTreatmentData', function(treatmentData)
    local src = source
    exports['QC-AdvancedMedic']:HandleTreatmentUpdate(src, treatmentData)
end)

-- Treatment removed event
RegisterNetEvent('QC-AdvancedMedic:server:TreatmentRemoved')
AddEventHandler('QC-AdvancedMedic:server:TreatmentRemoved', function(bodyPart, treatmentType, treatmentData)
    local src = source
    local Player, err = exports['QC-AdvancedMedic']:ValidatePlayer(src)
    if not Player then return end

    -- Log treatment removal
    pcall(function()
        exports['QC-AdvancedMedic']:LogMedicalEvent(
            Player.PlayerData.citizenid,
            'treatment_removed',
            bodyPart,
            {
                treatmentType = treatmentType,
                reason = treatmentData.reason or 'expired'
            }
        )
    end)
end)

-- Apply treatment to player (from medic) - LEGACY VERSION
-- NOTE: New code should use the server-authoritative system in treatments.lua
RegisterNetEvent('QC-AdvancedMedic:server:ApplyTreatment')
AddEventHandler('QC-AdvancedMedic:server:ApplyTreatment', function(targetPlayerId, treatmentType, itemType, bodyPart)
    local src = source

    -- Route to proper server-authoritative handler
    if treatmentType == 'bandage' then
        exports['QC-AdvancedMedic']:ApplyBandageToPlayer(src, targetPlayerId, {
            bodyPart = bodyPart,
            bandageType = itemType,
            itemName = itemType
        })
    elseif treatmentType == 'tourniquet' then
        exports['QC-AdvancedMedic']:ApplyTourniquetToPlayer(src, targetPlayerId, {
            bodyPart = bodyPart,
            tourniquetType = itemType,
            itemName = itemType
        })
    elseif treatmentType == 'medicine' then
        exports['QC-AdvancedMedic']:AdministreMedicineToPlayer(src, targetPlayerId, {
            medicineType = itemType,
            itemName = itemType
        })
    elseif treatmentType == 'injection' then
        exports['QC-AdvancedMedic']:AdministerInjectionToPlayer(src, targetPlayerId, {
            injectionType = itemType,
            itemName = itemType
        })
    end
end)

--=========================================================
-- INFECTION EVENTS
--=========================================================

-- Log infection cure
RegisterNetEvent('QC-AdvancedMedic:server:LogInfectionCure')
AddEventHandler('QC-AdvancedMedic:server:LogInfectionCure', function(bodyPart, treatmentItem)
    local src = source
    local Player, err = exports['QC-AdvancedMedic']:ValidatePlayer(src)
    if not Player then return end

    -- Log infection cure in medical history
    pcall(function()
        exports['QC-AdvancedMedic']:LogMedicalEvent(
            Player.PlayerData.citizenid,
            'infection_cured',
            bodyPart,
            {
                treatmentUsed = treatmentItem,
                curedBy = Player.PlayerData.citizenid
            }
        )
    end)
end)

-- Treat infection on another player
RegisterNetEvent('QC-AdvancedMedic:server:TreatInfection')
AddEventHandler('QC-AdvancedMedic:server:TreatInfection', function(targetPlayerId, bodyPart, treatmentItem)
    local src = source

    -- Use server-authoritative cure handler
    local success, err = exports['QC-AdvancedMedic']:HandleInfectionCure(targetPlayerId, bodyPart, treatmentItem)

    if not success then
        exports['QC-AdvancedMedic']:NotifyValidationError(src, err)
    end
end)

--=========================================================
-- MEDICAL BAG EVENTS
--=========================================================

-- Use medical bag
RegisterNetEvent('QC-AdvancedMedic:server:UseMedicalBag')
AddEventHandler('QC-AdvancedMedic:server:UseMedicalBag', function()
    local src = source
    local Player, err = exports['QC-AdvancedMedic']:ValidatePlayer(src)
    if not Player then return end

    -- Check if player has medical bag
    if not exports['QC-AdvancedMedic']:HasItem(src, 'medicbag') then
        exports['QC-AdvancedMedic']:NotifyError(src,
            locale('sv_error'),
            "You don't have a medical bag"
        )
        return
    end

    -- Open medical bag UI
    TriggerClientEvent('QC-AdvancedMedic:client:OpenMedicalBag', src)
end)

--=========================================================
-- MEDICAL INSPECTION EVENTS
--=========================================================

-- Start medical inspection
RegisterNetEvent('QC-AdvancedMedic:server:StartMedicalInspection')
AddEventHandler('QC-AdvancedMedic:server:StartMedicalInspection', function(targetPlayerId)
    local src = source

    -- Validate medic
    local Medic, err = exports['QC-AdvancedMedic']:ValidateMedic(src)
    if not Medic then
        exports['QC-AdvancedMedic']:NotifyValidationError(src, err)
        return
    end

    -- Validate target
    local Target, err2 = exports['QC-AdvancedMedic']:ValidatePlayer(targetPlayerId)
    if not Target then
        exports['QC-AdvancedMedic']:NotifyValidationError(src, err2)
        return
    end

    -- Check distance
    if not exports['QC-AdvancedMedic']:CheckDistance(src, targetPlayerId, 5.0) then
        exports['QC-AdvancedMedic']:NotifyValidationError(src, "TOO_FAR")
        return
    end

    -- Notify both players
    exports['QC-AdvancedMedic']:NotifyInfo(src,
        locale('sv_inspection_started'),
        string.format("Inspecting %s", Target.PlayerData.charinfo.firstname)
    )

    exports['QC-AdvancedMedic']:NotifyInfo(targetPlayerId,
        locale('sv_being_inspected'),
        string.format("Dr. %s is inspecting you", Medic.PlayerData.charinfo.lastname)
    )
end)

-- Complete medical inspection
RegisterNetEvent('QC-AdvancedMedic:server:CompleteMedicalInspection')
AddEventHandler('QC-AdvancedMedic:server:CompleteMedicalInspection', function(targetPlayerId, findings, treatments, notes)
    local src = source
    local Medic, err = exports['QC-AdvancedMedic']:ValidateMedic(src)
    if not Medic then return end

    local Target, err2 = exports['QC-AdvancedMedic']:ValidatePlayer(targetPlayerId)
    if not Target then return end

    -- Log inspection in medical history
    pcall(function()
        exports['QC-AdvancedMedic']:LogMedicalEvent(
            Target.PlayerData.citizenid,
            'medical_inspection',
            nil,
            {
                inspectedBy = Medic.PlayerData.citizenid,
                findings = findings,
                treatments = treatments,
                notes = notes
            }
        )
    end)

    exports['QC-AdvancedMedic']:NotifySuccess(src,
        locale('sv_inspection_complete'),
        "Medical inspection completed"
    )
end)

--=========================================================
-- FRACTURE EVENTS (Placeholder - for future implementation)
--=========================================================

RegisterNetEvent('QC-AdvancedMedic:server:SaveFracture')
AddEventHandler('QC-AdvancedMedic:server:SaveFracture', function(bodyPart, fractureData)
    local src = source
    local Player, err = exports['QC-AdvancedMedic']:ValidatePlayer(src)
    if not Player then return end

    pcall(function()
        exports['QC-AdvancedMedic']:SaveFractureData(Player.PlayerData.citizenid, bodyPart, fractureData)
    end)
end)

RegisterNetEvent('QC-AdvancedMedic:server:LoadFractures')
AddEventHandler('QC-AdvancedMedic:server:LoadFractures', function()
    local src = source
    local Player, err = exports['QC-AdvancedMedic']:ValidatePlayer(src)
    if not Player then return end

    local fractures = {}
    pcall(function()
        fractures = exports['QC-AdvancedMedic']:LoadFractureData(Player.PlayerData.citizenid) or {}
    end)

    if next(fractures) then
        TriggerClientEvent('QC-AdvancedMedic:client:LoadFractures', src, fractures)
    end
end)

--=========================================================
-- PLAYER LIFECYCLE EVENTS
--=========================================================

-- Player loaded event
RegisterNetEvent('RSGCore:Server:PlayerLoaded')
AddEventHandler('RSGCore:Server:PlayerLoaded', function()
    local src = source
    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[EVENTS] Player %d loaded - medical data will be requested by client^7", src))
    end
end)

--=========================================================
-- INITIALIZATION
--=========================================================

if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
    print("^2[SERVER EVENTS] Event handlers loaded^7")
end
