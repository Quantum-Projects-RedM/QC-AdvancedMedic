--=========================================================
-- QC-ADVANCED MEDIC - MAIN CLIENT ENTRY POINT
--=========================================================
-- Initialization and lifecycle management
-- Handles dependency loading, character spawn/logout events
-- Version: 0.4.0 Simplified (global bleeding, no body parts)
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
QCMed = QCMed or {}

--=========================================================
-- CHARACTER LIFECYCLE
--=========================================================

-- Character spawn - load medical data from server
RegisterNetEvent("RSGCore:Client:OnPlayerLoaded")
AddEventHandler("RSGCore:Client:OnPlayerLoaded", function()
    if Config.WoundSystem.debugging.enabled then
        print("^2[MAIN] Player loaded - requesting medical data from server^7")
    end

    -- Request medical data from server
    TriggerServerEvent('QC-AdvancedMedic:server:LoadMedicalData')

    -- Tourniquet expiration is handled by core_medical.lua's background thread
    -- using the global LocalPlayer.state.tourniquet (singular) timestamp pattern

    if Config.WoundSystem.debugging.enabled then
        print("^2[MAIN] Medical threads started^7")
    end
end)

-- Character logout - save and cleanup
RegisterNetEvent("RSGCore:Client:OnPlayerUnload")
AddEventHandler("RSGCore:Client:OnPlayerUnload", function()
    if Config.WoundSystem.debugging.enabled then
        print("^3[MAIN] Player unloading - saving medical data^7")
    end

    local state = QCMed.GetMedicalState and QCMed.GetMedicalState()
    if state then
        TriggerServerEvent('QC-AdvancedMedic:server:SaveMedicalDataOnDisconnect', state)
    end
end)

-- Death/respawn handling is fully managed by client/medical/death_system.lua

--=========================================================
-- ADMIN COMMANDS
--=========================================================

-- Admin revive command (clear all medical data + revive from death)
RegisterNetEvent('QC-AdvancedMedic:client:adminRevive')
AddEventHandler('QC-AdvancedMedic:client:adminRevive', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    -- Actually revive the player (required native to exit death state)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)

    -- Restore health
    SetEntityHealth(playerPed, Config.MaxHealth or 400)
    ClearPedTasksImmediately(playerPed)

    -- Clear all medical state (global bleeding + bandage cycles)
    if QCMed.ResetMedicalState then
        QCMed.ResetMedicalState()
    end

    -- Clear tourniquet state (global singular timestamp pattern)
    LocalPlayer.state:set('tourniquet', nil, false)

    -- Clear infections
    QCMed.ClearAllInfections()

    -- Clear movement overrides
    SetPedMoveRateOverride(playerPed, 1.0)
    ClearTimecycleModifier()

    -- Reset death state (death cam, NUI, death timer)
    TriggerEvent('QC-AdvancedMedic:client:ResetDeathState')

    -- Set server-side death metadata
    TriggerServerEvent('RSGCore:Server:SetMetaData', 'isdead', false)
    LocalPlayer.state:set('isDead', false, true)

    lib.notify({
        title = locale('sv_medical_system'),
        description = locale('sv_wounds_cleared'),
        type = 'success',
        duration = 5000
    })

    if Config.WoundSystem.debugging.enabled then
        print("^2[MAIN] Admin revive complete - all medical data cleared, death state reset^7")
    end
end)

-- Admin kill command
RegisterNetEvent('QC-AdvancedMedic:client:KillPlayer')
AddEventHandler('QC-AdvancedMedic:client:KillPlayer', function()
    local playerPed = PlayerPedId()

    -- Kill the player
    SetEntityHealth(playerPed, 0)

    -- Set death metadata
    TriggerServerEvent('RSGCore:Server:SetMetaData', 'isdead', true)
    LocalPlayer.state:set('isDead', true, true)

    -- Trigger death system (death cam, death timer, NUI)
    TriggerEvent('QC-AdvancedMedic:client:playerDied')

    if Config.WoundSystem.debugging.enabled then
        print("^1[MAIN] Player killed by admin command^7")
    end
end)

-- Clear all wounds (admin command)
RegisterNetEvent('QC-AdvancedMedic:client:ClearAllWounds')
AddEventHandler('QC-AdvancedMedic:client:ClearAllWounds', function()
    if QCMed.ResetMedicalState then
        QCMed.ResetMedicalState()
    end

    lib.notify({
        title = locale('sv_medical_system'),
        description = locale('sv_wounds_cleared'),
        type = 'success',
        duration = 5000
    })

    if Config.WoundSystem.debugging.enabled then
        print("^2[MAIN] All wounds cleared^7")
    end
end)

--=========================================================
-- INITIALIZATION
--=========================================================

if Config.WoundSystem.debugging.enabled then
    print("^2[QC-ADVANCEDMEDIC] Main client entry point loaded^7")
    print("^2[QC-ADVANCEDMEDIC] Medical systems initialized^7")
    print("^2[QC-ADVANCEDMEDIC] Version: 0.4.0 Simplified^7")
end
