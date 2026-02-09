--=========================================================
-- QC-ADVANCED MEDIC - WOUND SYSTEM (SERVER)
--=========================================================
-- Server-side wound data management with validation
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
QCMedServer = QCMedServer or {}

--=========================================================
-- WOUND DATA OPERATIONS
--=========================================================

-- Handle wound update with validation
local function HandleWoundUpdate(source, woundData)
    -- Validate player
    local Player, err = QCMedServer.ValidatePlayer(source)
    if not Player then
        return false, err
    end

    -- Validate wound data structure
    local valid, validErr = QCMedServer.ValidateWoundData(woundData)
    if not valid then
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^1[WOUNDS] Invalid wound data from player %d: %s^7", source, validErr))
        end
        return false, validErr
    end

    -- Save to database
    local success = pcall(function()
        QCMedServer.SaveWoundData(Player.PlayerData.citizenid, woundData)

        -- Broadcast to nearby players for medic inspection
        BroadcastWoundUpdate(source, woundData)
    end)

    if success then
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^2[WOUNDS] Saved wound data for player %d^7", source))
        end
        return true
    else
        return false, "DATABASE_ERROR"
    end
end

-- Broadcast wound updates to nearby players
local function BroadcastWoundUpdate(source, woundData)
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local players = RSGCore.Functions.GetRSGPlayers()

    for _, player in pairs(players) do
        if player.PlayerData.source ~= source then
            local targetCoords = GetEntityCoords(GetPlayerPed(player.PlayerData.source))
            local distance = #(playerCoords - targetCoords)

            if distance <= 10.0 then -- Within 10 meters
                TriggerClientEvent('QC-AdvancedMedic:client:UpdateNearbyPlayerWounds',
                    player.PlayerData.source, source, woundData)
            end
        end
    end
end

-- Handle wound removal
local function HandleWoundRemoval(source, bodyPart)
    local Player, err = QCMedServer.ValidatePlayer(source)
    if not Player then
        return false, err
    end

    -- Validate body part
    if not Config.BodyParts[bodyPart] then
        return false, "INVALID_BODY_PART"
    end

    -- Remove from database
    local success = pcall(function()
        QCMedServer.RemoveWound(Player.PlayerData.citizenid, bodyPart)
    end)

    return success, success and nil or "DATABASE_ERROR"
end

-- Save scar data
local function HandleScarSave(source, scarData)
    local Player, err = QCMedServer.ValidatePlayer(source)
    if not Player then
        return false, err
    end

    local success = pcall(function()
        QCMedServer.SaveScarData(Player.PlayerData.citizenid, scarData)
    end)

    return success, success and nil or "DATABASE_ERROR"
end

--=========================================================
-- EXPORTS
--=========================================================

QCMedServer.HandleWoundUpdate = HandleWoundUpdate
QCMedServer.HandleWoundRemoval = HandleWoundRemoval
QCMedServer.HandleScarSave = HandleScarSave
QCMedServer.BroadcastWoundUpdate = BroadcastWoundUpdate

if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
    print("^2[SERVER WOUNDS] Wound system loaded^7")
end
