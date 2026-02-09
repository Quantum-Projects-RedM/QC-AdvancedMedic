--=========================================================
-- QC-ADVANCED MEDIC - EVENT HANDLERS
--=========================================================
-- Server network event handlers for medical system
-- Version: 0.4.0 Simplified (global bleeding + bandage cycles)
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
QCMedServer = QCMedServer or {}

--=========================================================
-- MEDICAL DATA PERSISTENCE
--=========================================================

-- Load all medical data from database when player spawns
RegisterNetEvent('QC-AdvancedMedic:server:LoadMedicalData')
AddEventHandler('QC-AdvancedMedic:server:LoadMedicalData', function()
    local src = source
    local Player, err = QCMedServer.ValidatePlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Load medical data safely
    local woundData = {}
    local infections = {}

    pcall(function()
        woundData = QCMedServer.LoadWoundData(citizenid) or {}
    end)

    pcall(function()
        infections = QCMedServer.LoadInfectionData(citizenid) or {}
    end)

    -- Send wound/medical state to client
    if next(woundData) then
        TriggerClientEvent('QC-AdvancedMedic:client:LoadWounds', src, woundData)
    end

    -- Send infection data
    if infections and infections.level and infections.level > 0 then
        TriggerClientEvent('QC-AdvancedMedic:client:LoadInfections', src, infections)
    end

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[EVENTS] Loaded medical data for player %s (bleeding: %.1f)^7",
            src, woundData.bleedingLevel or 0))
    end
end)

-- Save medical data on disconnect (receives full MedicalState from client)
RegisterNetEvent('QC-AdvancedMedic:server:SaveMedicalDataOnDisconnect')
AddEventHandler('QC-AdvancedMedic:server:SaveMedicalDataOnDisconnect', function(medicalState)
    local src = source
    local Player, err = QCMedServer.ValidatePlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Save all medical data
    pcall(function()
        if medicalState then
            QCMedServer.SaveWoundData(citizenid, medicalState)

            -- Save active bandage if present
            if medicalState.activeBandage then
                QCMedServer.SaveTreatmentData(citizenid, { activeBandage = medicalState.activeBandage })
            end
        end
    end)

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[EVENTS] Saved medical data on disconnect for player %s^7", tostring(src)))
    end
end)

--=========================================================
-- WOUND DATA EVENTS
--=========================================================

-- Update wound data (global medical state from client)
RegisterNetEvent('QC-AdvancedMedic:server:UpdateWoundData')
AddEventHandler('QC-AdvancedMedic:server:UpdateWoundData', function(medicalState)
    local src = source
    local Player, err = QCMedServer.ValidatePlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    pcall(function()
        QCMedServer.SaveWoundData(citizenid, medicalState)
    end)
end)

-- Request wound data for another player (for medic inspection)
-- Reads live medical state from target player's state bag (synced in real-time)
RegisterNetEvent('QC-AdvancedMedic:server:RequestWoundData')
AddEventHandler('QC-AdvancedMedic:server:RequestWoundData', function(targetPlayerId)
    local src = source

    -- Validate requesting player is medic
    local Medic, err = QCMedServer.ValidateMedic(src)
    if not Medic then
        QCMedServer.NotifyValidationError(src, err)
        return
    end

    -- Validate target player
    local Target, err2 = QCMedServer.ValidatePlayer(targetPlayerId)
    if not Target then
        QCMedServer.NotifyValidationError(src, err2)
        return
    end

    -- Read live medical state from target player's state bag
    local liveState = Player(targetPlayerId).state.medicalData

    local woundData = {}
    if liveState then
        woundData = liveState
    else
        -- Fallback to DB if state bag not yet set (e.g. just loaded)
        pcall(function()
            woundData = QCMedServer.LoadWoundData(Target.PlayerData.citizenid) or {}
        end)
    end

    -- Send to requesting medic
    TriggerClientEvent('QC-AdvancedMedic:client:ReceiveWoundData', src, targetPlayerId, woundData)
end)

--=========================================================
-- TREATMENT EVENTS
--=========================================================

-- Apply treatment to player (from medic) - simplified, no body part
RegisterNetEvent('QC-AdvancedMedic:server:ApplyTreatment')
AddEventHandler('QC-AdvancedMedic:server:ApplyTreatment', function(targetPlayerId, treatmentType, itemType)
    local src = source

    if treatmentType == 'bandage' then
        -- Trigger client-side bandage application on target
        TriggerClientEvent('QC-AdvancedMedic:client:CheckForSelfTreatment', targetPlayerId, 'bandage', itemType)
    elseif treatmentType == 'tourniquet' then
        TriggerClientEvent('QC-AdvancedMedic:client:CheckForSelfTreatment', targetPlayerId, 'tourniquet', itemType)
    elseif treatmentType == 'medicine' then
        TriggerClientEvent('QC-AdvancedMedic:client:CheckForSelfTreatment', targetPlayerId, 'medicine', itemType)
    elseif treatmentType == 'injection' then
        TriggerClientEvent('QC-AdvancedMedic:client:CheckForSelfTreatment', targetPlayerId, 'injection', itemType)
    end
end)

--=========================================================
-- INFECTION EVENTS
--=========================================================

-- Update infection data from client
RegisterNetEvent('QC-AdvancedMedic:server:UpdateInfectionData')
AddEventHandler('QC-AdvancedMedic:server:UpdateInfectionData', function(infectionData)
    local src = source
    local Player, err = QCMedServer.ValidatePlayer(src)
    if not Player then return end

    pcall(function()
        QCMedServer.SaveInfectionData(Player.PlayerData.citizenid, infectionData)
    end)
end)

-- Log infection cure
RegisterNetEvent('QC-AdvancedMedic:server:LogInfectionCure')
AddEventHandler('QC-AdvancedMedic:server:LogInfectionCure', function(treatmentItem)
    local src = source
    local Player, err = QCMedServer.ValidatePlayer(src)
    if not Player then return end

    pcall(function()
        QCMedServer.LogMedicalEvent(
            Player.PlayerData.citizenid,
            'infection_cured',
            nil,
            {
                treatmentUsed = treatmentItem,
                curedBy = Player.PlayerData.citizenid
            }
        )
    end)
end)

--=========================================================
-- MEDICAL BAG EVENTS
--=========================================================

-- Use medical bag
RegisterNetEvent('QC-AdvancedMedic:server:UseMedicalBag')
AddEventHandler('QC-AdvancedMedic:server:UseMedicalBag', function()
    local src = source
    local Player, err = QCMedServer.ValidatePlayer(src)
    if not Player then return end

    -- Check if player has medical bag
    if not QCMedServer.HasItem(src, 'medicbag') then
        QCMedServer.NotifyError(src,
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
    local Medic, err = QCMedServer.ValidateMedic(src)
    if not Medic then
        QCMedServer.NotifyValidationError(src, err)
        return
    end

    -- Validate target
    local Target, err2 = QCMedServer.ValidatePlayer(targetPlayerId)
    if not Target then
        QCMedServer.NotifyValidationError(src, err2)
        return
    end

    -- Check distance
    if not QCMedServer.CheckDistance(src, targetPlayerId, 5.0) then
        QCMedServer.NotifyValidationError(src, "TOO_FAR")
        return
    end

    -- Notify both players
    QCMedServer.NotifyInfo(src,
        locale('sv_inspection_started'),
        string.format("Inspecting %s", Target.PlayerData.charinfo.firstname)
    )

    QCMedServer.NotifyInfo(targetPlayerId,
        locale('sv_being_inspected'),
        string.format("Dr. %s is inspecting you", Medic.PlayerData.charinfo.lastname)
    )
end)

-- Complete medical inspection
RegisterNetEvent('QC-AdvancedMedic:server:CompleteMedicalInspection')
AddEventHandler('QC-AdvancedMedic:server:CompleteMedicalInspection', function(targetPlayerId, findings, treatments, notes)
    local src = source
    local Medic, err = QCMedServer.ValidateMedic(src)
    if not Medic then return end

    local Target, err2 = QCMedServer.ValidatePlayer(targetPlayerId)
    if not Target then return end

    -- Log inspection in medical history
    pcall(function()
        QCMedServer.LogMedicalEvent(
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

    QCMedServer.NotifySuccess(src,
        locale('sv_inspection_complete'),
        "Medical inspection completed"
    )
end)

--=========================================================
-- FRACTURE EVENTS
--=========================================================

RegisterNetEvent('QC-AdvancedMedic:server:SaveFracture')
AddEventHandler('QC-AdvancedMedic:server:SaveFracture', function(bodyPart, fractureData)
    local src = source
    local Player, err = QCMedServer.ValidatePlayer(src)
    if not Player then return end

    pcall(function()
        QCMedServer.SaveFractureData(Player.PlayerData.citizenid, bodyPart, fractureData)
    end)
end)

RegisterNetEvent('QC-AdvancedMedic:server:LoadFractures')
AddEventHandler('QC-AdvancedMedic:server:LoadFractures', function()
    local src = source
    local Player, err = QCMedServer.ValidatePlayer(src)
    if not Player then return end

    local fractures = {}
    pcall(function()
        fractures = QCMedServer.LoadFractureData(Player.PlayerData.citizenid) or {}
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
        print(string.format("^2[EVENTS] Player %s loaded - medical data will be requested by client^7", tostring(src)))
    end
end)

--=========================================================
-- INITIALIZATION
--=========================================================

if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
    print("^2[SERVER EVENTS] Event handlers loaded (v0.4.0 Simplified)^7")
end
