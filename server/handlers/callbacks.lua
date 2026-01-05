--=========================================================
-- QC-ADVANCED MEDIC - CALLBACK HANDLERS
--=========================================================
-- Server-authoritative callback system for medical operations
-- Handles client → server → database → client response flow
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

--=========================================================
-- CALLBACK RESPONSE HELPER
--=========================================================

-- Send callback response to client
local function SendCallbackResponse(source, callbackId, success, ...)
    TriggerClientEvent('QC-AdvancedMedic:client:CallbackResponse', source, callbackId, success, ...)
end

--=========================================================
-- CALLBACK REQUEST ROUTER
--=========================================================

-- Generic callback router for server-authoritative operations
RegisterNetEvent('QC-AdvancedMedic:server:CallbackRequest')
AddEventHandler('QC-AdvancedMedic:server:CallbackRequest', function(eventName, callbackId, data)
    local src = source

    -- Route to appropriate handler based on event name
    if eventName == 'UpdateWoundData' then
        HandleUpdateWoundDataCallback(src, callbackId, data)
    elseif eventName == 'UpdateTreatmentData' then
        HandleUpdateTreatmentDataCallback(src, callbackId, data)
    elseif eventName == 'UpdateInfectionData' then
        HandleUpdateInfectionDataCallback(src, callbackId, data)
    elseif eventName == 'RemoveWound' then
        HandleRemoveWoundCallback(src, callbackId, data)
    elseif eventName == 'SaveScarData' then
        HandleSaveScarDataCallback(src, callbackId, data)
    elseif eventName == 'SaveBulletRemoval' then
        HandleSaveBulletRemovalCallback(src, callbackId, data)
    else
        -- Unknown event - send failure response
        SendCallbackResponse(src, callbackId, false, "UNKNOWN_EVENT")

        if Config.WoundSystem.debugging.enabled then
            print(string.format("^3[CALLBACK] Unknown event: %s from player %d^7", eventName, src))
        end
    end
end)

--=========================================================
-- CALLBACK HANDLERS
--=========================================================

-- Handle wound data update callback
function HandleUpdateWoundDataCallback(source, callbackId, woundData)
    local success, err = exports['QC-AdvancedMedic']:HandleWoundUpdate(source, woundData)

    if success then
        SendCallbackResponse(source, callbackId, true)
    else
        SendCallbackResponse(source, callbackId, false, err or "DATABASE_ERROR")
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^1[CALLBACK ERROR] UpdateWoundData failed: %s^7", tostring(err)))
        end
    end
end

-- Handle treatment data update callback
function HandleUpdateTreatmentDataCallback(source, callbackId, treatmentData)
    local success, err = exports['QC-AdvancedMedic']:HandleTreatmentUpdate(source, treatmentData)

    if success then
        SendCallbackResponse(source, callbackId, true)
    else
        SendCallbackResponse(source, callbackId, false, err or "DATABASE_ERROR")
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^1[CALLBACK ERROR] UpdateTreatmentData failed: %s^7", tostring(err)))
        end
    end
end

-- Handle infection data update callback
function HandleUpdateInfectionDataCallback(source, callbackId, infectionData)
    local success, err = exports['QC-AdvancedMedic']:HandleInfectionUpdate(source, infectionData)

    if success then
        SendCallbackResponse(source, callbackId, true)
    else
        SendCallbackResponse(source, callbackId, false, err or "DATABASE_ERROR")
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^1[CALLBACK ERROR] UpdateInfectionData failed: %s^7", tostring(err)))
        end
    end
end

-- Handle wound removal callback
function HandleRemoveWoundCallback(source, callbackId, data)
    local success, err = exports['QC-AdvancedMedic']:HandleWoundRemoval(source, data.bodyPart)

    if success then
        SendCallbackResponse(source, callbackId, true)
    else
        SendCallbackResponse(source, callbackId, false, err or "DATABASE_ERROR")
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^1[CALLBACK ERROR] RemoveWound failed: %s^7", tostring(err)))
        end
    end
end

-- Handle scar data save callback
function HandleSaveScarDataCallback(source, callbackId, scarData)
    local success, err = exports['QC-AdvancedMedic']:HandleScarSave(source, scarData)

    if success then
        SendCallbackResponse(source, callbackId, true)
    else
        SendCallbackResponse(source, callbackId, false, err or "DATABASE_ERROR")
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^1[CALLBACK ERROR] SaveScarData failed: %s^7", tostring(err)))
        end
    end
end

-- Handle bullet removal callback
function HandleSaveBulletRemovalCallback(source, callbackId, data)
    local Player, err = exports['QC-AdvancedMedic']:ValidatePlayer(source)
    if not Player then
        SendCallbackResponse(source, callbackId, false, err)
        return
    end

    -- Save bullet removal to database
    local success, dbErr = pcall(function()
        exports['QC-AdvancedMedic']:SaveBulletRemoval(
            Player.PlayerData.citizenid,
            data.bodyPart,
            data.woundData
        )
    end)

    if success then
        SendCallbackResponse(source, callbackId, true)
    else
        SendCallbackResponse(source, callbackId, false, "DATABASE_ERROR", tostring(dbErr))
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^1[CALLBACK ERROR] SaveBulletRemoval failed: %s^7", tostring(dbErr)))
        end
    end
end

--=========================================================
-- INITIALIZATION
--=========================================================

if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
    print("^2[SERVER CALLBACKS] Callback handlers loaded^7")
end
