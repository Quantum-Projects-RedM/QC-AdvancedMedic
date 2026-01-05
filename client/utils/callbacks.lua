--=========================================================
-- QC-ADVANCED MEDIC - CALLBACK SYSTEM
--=========================================================
-- Server-authoritative callbacks with acknowledgment and rollback support
-- Prevents client-server desynchronization in medical data updates
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

-- Active callback storage
local _activeCallbacks = {}
local _callbackId = 0

--=========================================================
-- CALLBACK REQUEST SYSTEM
--=========================================================
-- Sends a callback request to server and waits for acknowledgment
-- @param eventName string - The server event to trigger
-- @param data any - Data to send to server
-- @param callback function - Function to call when server responds
-- @param timeout number - Optional timeout in milliseconds (default: 5000)
--=========================================================
local function ServerCallback(eventName, data, callback, timeout)
    timeout = timeout or 5000

    -- Generate unique callback ID
    _callbackId = _callbackId + 1
    local callbackId = _callbackId

    -- Store callback for response
    _activeCallbacks[callbackId] = {
        callback = callback,
        timeout = GetGameTimer() + timeout,
        event = eventName
    }

    -- Send request to server
    TriggerServerEvent('QC-AdvancedMedic:server:CallbackRequest', eventName, callbackId, data)

    -- Setup timeout handler
    CreateThread(function()
        Wait(timeout)

        -- Check if callback still pending
        if _activeCallbacks[callbackId] then
            local cb = _activeCallbacks[callbackId].callback
            _activeCallbacks[callbackId] = nil

            -- Notify callback of timeout
            if cb then
                cb(false, "TIMEOUT")
            end

            if Config.WoundSystem.debugging.enabled then
                print(string.format("^3[CALLBACK TIMEOUT] %s (ID: %d)^7", eventName, callbackId))
            end
        end
    end)
end

--=========================================================
-- CALLBACK RESPONSE HANDLER
--=========================================================
-- Receives server responses and executes stored callbacks
RegisterNetEvent('QC-AdvancedMedic:client:CallbackResponse')
AddEventHandler('QC-AdvancedMedic:client:CallbackResponse', function(callbackId, success, ...)
    local callbackData = _activeCallbacks[callbackId]

    if not callbackData then
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^3[CALLBACK] Received response for unknown callback ID: %d^7", callbackId))
        end
        return
    end

    -- Remove from active callbacks
    _activeCallbacks[callbackId] = nil

    -- Execute callback with server response
    if callbackData.callback then
        callbackData.callback(success, ...)
    end

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[CALLBACK SUCCESS] %s (ID: %d) - Success: %s^7",
            callbackData.event, callbackId, tostring(success)))
    end
end)

--=========================================================
-- CLEANUP THREAD
--=========================================================
-- Periodically cleans up expired callbacks
CreateThread(function()
    while true do
        Wait(10000) -- Check every 10 seconds

        local currentTime = GetGameTimer()
        local expiredCount = 0

        for callbackId, data in pairs(_activeCallbacks) do
            if data.timeout < currentTime then
                -- Timeout exceeded, clean up
                if data.callback then
                    data.callback(false, "TIMEOUT")
                end

                _activeCallbacks[callbackId] = nil
                expiredCount = expiredCount + 1
            end
        end

        if expiredCount > 0 and Config.WoundSystem.debugging.enabled then
            print(string.format("^3[CALLBACK CLEANUP] Removed %d expired callbacks^7", expiredCount))
        end
    end
end)

--=========================================================
-- EXPORTED FUNCTIONS
--=========================================================
exports('ServerCallback', ServerCallback)

-- Global namespace for easy access
QCMedic = QCMedic or {}
QCMedic.Callbacks = {
    ServerCallback = ServerCallback
}

-- Return module
return {
    ServerCallback = ServerCallback
}
