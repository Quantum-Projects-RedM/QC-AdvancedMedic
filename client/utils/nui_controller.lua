--=========================================================
-- QC-ADVANCED MEDIC - NUI CONTROLLER
--=========================================================
-- Handles all NUI (UI) updates and synchronization
-- Sends medical data to the React UI
-- Version: 0.4.0 Simplified (global bleeding, no body parts)
--=========================================================

QCMed = QCMed or {}

local nuiFocusEnabled = false

--=========================================================
-- HELPER FUNCTIONS
--=========================================================

-- Get global medical state for NUI
local function GetMedicalNUIData()
    local medicalState = QCMed.GetMedicalState()
    local infectionData = QCMed.GetGlobalInfection()
    local fractures = QCMed.GetPlayerFractures()

    return {
        bleedingLevel = medicalState.bleedingLevel or 0,
        bandageChangesNeeded = medicalState.bandageChangesNeeded or 0,
        bandageChangesApplied = medicalState.bandageChangesApplied or 0,
        activeBandage = medicalState.activeBandage,
        lastWoundSource = medicalState.lastWoundSource,
        infection = infectionData,
        fractures = fractures or {},
        tourniquet = LocalPlayer.state.tourniquet,
    }
end

-- Update NUI with latest medical data
local function UpdateMedicalNUI()
    local data = GetMedicalNUIData()

    SendNUIMessage({
        type = 'update-medical-data',
        data = data
    })
end

--=========================================================
-- EVENT HANDLERS
--=========================================================

-- Load medical state from server (replaces per-body-part wound loading)
RegisterNetEvent('QC-AdvancedMedic:client:LoadMedicalState')
AddEventHandler('QC-AdvancedMedic:client:LoadMedicalState', function(stateData)
    if not stateData then return end

    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        print("^2[NUI] Received medical state data from server^7")
    end

    -- Update NUI
    CreateThread(function()
        Wait(100) -- Small delay to ensure data is processed
        UpdateMedicalNUI()
    end)
end)

-- Legacy wound loading handler (redirects to new system)
RegisterNetEvent('QC-AdvancedMedic:client:LoadWounds')
AddEventHandler('QC-AdvancedMedic:client:LoadWounds', function(woundData)
    if not woundData then return end

    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        print("^2[NUI] Loaded wound data from server^7")
    end

    UpdateMedicalNUI()
end)

-- Load infections from server
RegisterNetEvent('QC-AdvancedMedic:client:LoadInfections')
AddEventHandler('QC-AdvancedMedic:client:LoadInfections', function(infections)
    if not infections then return end

    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        print("^2[NUI] Received infections data from server^7")
    end

    UpdateMedicalNUI()
end)

-- Show inspection panel
RegisterNetEvent('QC-AdvancedMedic:client:ShowInspectionPanel')
AddEventHandler('QC-AdvancedMedic:client:ShowInspectionPanel', function(inspectionData)
    SendNUIMessage({
        type = 'show-inspection-panel',
        data = inspectionData
    })

    SetNuiFocus(true, true)
    nuiFocusEnabled = true
end)

-- Hide inspection panel
RegisterNetEvent('QC-AdvancedMedic:client:HideInspectionPanel')
AddEventHandler('QC-AdvancedMedic:client:HideInspectionPanel', function()
    SendNUIMessage({
        type = 'hide-inspection-panel'
    })

    SetNuiFocus(false, false)
    nuiFocusEnabled = false
end)

-- Vitals response for medic
RegisterNetEvent('QC-AdvancedMedic:client:VitalsResponse')
AddEventHandler('QC-AdvancedMedic:client:VitalsResponse', function(vitalsData)
    SendNUIMessage({
        type = 'show-vitals',
        data = vitalsData
    })
end)

--=========================================================
-- NUI CALLBACKS
--=========================================================

-- Handle NUI callbacks from React UI
RegisterNUICallback('closeInspection', function(data, cb)
    TriggerEvent('QC-AdvancedMedic:client:HideInspectionPanel')
    cb('ok')
end)

RegisterNUICallback('applyTreatment', function(data, cb)
    -- data contains: { targetPlayerId, treatmentType, itemType }
    TriggerServerEvent('QC-AdvancedMedic:server:ApplyTreatment',
        data.targetPlayerId,
        data.treatmentType,
        data.itemType
    )
    cb('ok')
end)

--=========================================================
-- EXPORTS
--=========================================================

QCMed.UpdateMedicalNUI = UpdateMedicalNUI
QCMed.GetMedicalNUIData = GetMedicalNUIData
QCMed.IsNUIFocused = function() return nuiFocusEnabled end
