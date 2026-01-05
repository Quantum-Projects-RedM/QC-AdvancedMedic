--=========================================================
-- QC-ADVANCED MEDIC - NUI CONTROLLER
--=========================================================
-- Handles all NUI (UI) updates and synchronization
-- Sends medical data to the React UI
--=========================================================

local nuiFocusEnabled = false

--=========================================================
-- HELPER FUNCTIONS
--=========================================================

-- Get body part health data for NUI
local function GetBodyPartHealthData()
    local bodyPartHealth = {}

    for bodyPart, config in pairs(Config.BodyParts) do
        local health = config.maxHealth or 100

        -- Reduce health based on wounds
        local wounds = exports['QC-AdvancedMedic']:GetMedicalState('wounds')
        if wounds and wounds[bodyPart] and not wounds[bodyPart].isScar then
            local wound = wounds[bodyPart]
            health = health - (wound.painLevel or 0) - (wound.bleedingLevel or 0)
        end

        bodyPartHealth[bodyPart] = math.max(0, health)
    end

    return bodyPartHealth
end

-- Update NUI with latest medical data
local function UpdateMedicalNUI()
    local wounds = exports['QC-AdvancedMedic']:GetMedicalState('wounds') or {}
    local treatments = exports['QC-AdvancedMedic']:GetMedicalState('treatments') or {}
    local infections = exports['QC-AdvancedMedic']:GetMedicalState('infections') or {}
    local bodyPartHealth = GetBodyPartHealthData()

    -- Convert treatments to array for NUI
    local treatmentsArray = {}
    for bodyPart, treatment in pairs(treatments) do
        table.insert(treatmentsArray, {
            bodyPart = bodyPart,
            type = treatment.treatmentType,
            itemType = treatment.itemType,
            appliedTime = treatment.appliedTime,
            effectiveness = treatment.effectiveness,
            appliedBy = treatment.appliedBy
        })
    end

    SendNUIMessage({
        type = 'update-medical-data',
        data = {
            wounds = wounds,
            treatments = treatmentsArray,
            infections = infections,
            bodyPartHealth = bodyPartHealth
        }
    })
end

--=========================================================
-- EVENT HANDLERS
--=========================================================

-- Load treatments from server
RegisterNetEvent('QC-AdvancedMedic:client:LoadTreatments')
AddEventHandler('QC-AdvancedMedic:client:LoadTreatments', function(treatments)
    if not treatments then
        if Config.WoundSystem.debugging.enabled then
            print("^1[NUI] Received nil treatments data^7")
        end
        return
    end

    -- Update MedicalState
    local state = exports['QC-AdvancedMedic']:GetMedicalState()
    state.treatments = treatments

    if Config.WoundSystem.debugging.enabled then
        print("^2[NUI] Received treatments data from server^7")
        local treatmentCount = 0
        for _ in pairs(treatments) do treatmentCount = treatmentCount + 1 end
        print("^3[NUI] Loaded " .. treatmentCount .. " active treatments^7")
    end

    -- Update NUI
    CreateThread(function()
        Wait(100) -- Small delay to ensure data is processed
        UpdateMedicalNUI()
    end)
end)

-- Load wounds from server
RegisterNetEvent('QC-AdvancedMedic:client:LoadWounds')
AddEventHandler('QC-AdvancedMedic:client:LoadWounds', function(wounds)
    if not wounds then return end

    -- Update MedicalState
    local state = exports['QC-AdvancedMedic']:GetMedicalState()
    state.wounds = wounds

    if Config.WoundSystem.debugging.enabled then
        local woundCount = 0
        for _ in pairs(wounds) do woundCount = woundCount + 1 end
        print("^2[NUI] Loaded " .. woundCount .. " wounds^7")
    end

    -- Update NUI
    UpdateMedicalNUI()
end)

-- Load infections from server
RegisterNetEvent('QC-AdvancedMedic:client:LoadInfections')
AddEventHandler('QC-AdvancedMedic:client:LoadInfections', function(infections)
    if not infections then return end

    -- Update MedicalState
    local state = exports['QC-AdvancedMedic']:GetMedicalState()
    state.infections = infections

    if Config.WoundSystem.debugging.enabled then
        print("^2[NUI] Received infections data from server^7")
    end

    -- Update NUI
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
    -- data contains: { bodyPart, treatmentType, itemType }
    TriggerServerEvent('QC-AdvancedMedic:server:ApplyTreatment',
        data.targetPlayerId,
        data.treatmentType,
        data.itemType,
        data.bodyPart
    )
    cb('ok')
end)

--=========================================================
-- EXPORTS
--=========================================================

exports('UpdateMedicalNUI', UpdateMedicalNUI)
exports('GetBodyPartHealthData', GetBodyPartHealthData)
exports('IsNUIFocused', function() return nuiFocusEnabled end)
