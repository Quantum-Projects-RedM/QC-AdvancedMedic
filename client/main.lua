--=========================================================
-- QC-ADVANCED MEDIC - MAIN CLIENT ENTRY POINT
--=========================================================
-- Initialization and lifecycle management
-- Handles dependency loading, character spawn/logout events
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

-- Core systems (loaded after dependencies)
local MEDICAL = nil
local HELPERS = nil

--=========================================================
-- DEPENDENCY LOADING
--=========================================================

-- Wait for core systems to be ready
AddEventHandler("Core:Shared:Ready", function()
    -- Load medical system exports
    MEDICAL = {
        GetState = function(key) return exports['QC-AdvancedMedic']:GetMedicalState(key) end,
        ApplyBandage = function(...) return exports['QC-AdvancedMedic']:ApplyBandage(...) end,
        ApplyTourniquet = function(...) return exports['QC-AdvancedMedic']:ApplyTourniquet(...) end,
        CreateWound = function(...) return exports['QC-AdvancedMedic']:CreateWound(...) end,
        ProcessHealing = function() return exports['QC-AdvancedMedic']:ProcessHealing() end,
    }

    -- Load helper utilities
    HELPERS = {
        IsMedicJob = function(...) return exports['QC-AdvancedMedic']:IsMedicJob(...) end,
        GetBodyPartLabel = function(...) return exports['QC-AdvancedMedic']:GetBodyPartLabel(...) end,
        CalculateHealthStatus = function() return exports['QC-AdvancedMedic']:CalculateHealthStatus() end,
    }

    if Config.WoundSystem.debugging.enabled then
        print("^2[MAIN] Core medical systems loaded^7")
    end
end)

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

    -- Start healing process thread
    CreateThread(function()
        while LocalPlayer.state.loggedIn do
            Wait(60000) -- Every minute
            if MEDICAL and MEDICAL.ProcessHealing then
                MEDICAL.ProcessHealing()
            end
        end
    end)

    -- Start treatment expiration checker (timestamp pattern)
    CreateThread(function()
        while LocalPlayer.state.loggedIn do
            local currentTime = GetGameTimer()

            -- Check tourniquet expiration
            local tourniquets = LocalPlayer.state.tourniquets
            if tourniquets then
                for bodyPart, expirationTime in pairs(tourniquets) do
                    if currentTime >= expirationTime then
                        exports['QC-AdvancedMedic']:RemoveTourniquet(bodyPart, "expired")
                    end
                end
                Wait(1000) -- Active check every 1 second
            else
                Wait(5000) -- Idle check every 5 seconds
            end
        end
    end)

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

    if MEDICAL then
        local state = MEDICAL.GetState()
        TriggerServerEvent('QC-AdvancedMedic:server:SaveMedicalDataOnDisconnect',
            state.wounds or {},
            state.treatments or {},
            state.infections or {}
        )
    end
end)

--=========================================================
-- CHARACTER DEATH/RESPAWN HANDLING
--=========================================================

-- Handle player death
RegisterNetEvent('QC-AdvancedMedic:client:playerDied')
AddEventHandler('QC-AdvancedMedic:client:playerDied', function()
    if Config.WoundSystem.debugging.enabled then
        print("^1[MAIN] Player died^7")
    end

    -- Death handling logic (preserve existing from client.lua)
    -- Will be migrated from existing client.lua in next iteration
end)

-- Handle player respawn/revive
RegisterNetEvent('QC-AdvancedMedic:client:playerRevived')
AddEventHandler('QC-AdvancedMedic:client:playerRevived', function()
    if Config.WoundSystem.debugging.enabled then
        print("^2[MAIN] Player revived^7")
    end

    -- Revive handling logic
    -- Will be migrated from existing client.lua in next iteration
end)

--=========================================================
-- ADMIN COMMANDS
--=========================================================

-- Admin revive command (clear all medical data)
RegisterNetEvent('QC-AdvancedMedic:client:adminRevive')
AddEventHandler('QC-AdvancedMedic:client:adminRevive', function()
    local playerPed = PlayerPedId()

    -- Restore health
    SetEntityHealth(playerPed, Config.MaxHealth or 400)

    -- Clear wounds, treatments, infections
    if MEDICAL then
        local state = MEDICAL.GetState()
        state.wounds = {}
        state.treatments = {}
        state.healingTimers = {}
        state.infectionData = {}

        -- Update backwards compatibility globals
        PlayerWounds = {}
        ActiveTreatments = {}
    end

    -- Clear tourniquet state
    LocalPlayer.state:set('tourniquets', {}, false)

    lib.notify({
        title = locale('sv_medical_system'),
        description = locale('sv_wounds_cleared'),
        type = 'success',
        duration = 5000
    })

    if Config.WoundSystem.debugging.enabled then
        print("^2[MAIN] Admin revive complete - all medical data cleared^7")
    end
end)

-- Clear all wounds (admin command)
RegisterNetEvent('QC-AdvancedMedic:client:ClearAllWounds')
AddEventHandler('QC-AdvancedMedic:client:ClearAllWounds', function()
    if MEDICAL then
        local state = MEDICAL.GetState()
        state.wounds = {}
        state.treatments = {}
        state.healingTimers = {}

        -- Update backwards compatibility globals
        PlayerWounds = {}
        ActiveTreatments = {}
    end

    TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', {})

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
    print("^2[QC-ADVANCEDMEDIC] Version: 0.3.1 Refactored^7")
end
