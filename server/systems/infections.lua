--=========================================================
-- QC-ADVANCED MEDIC - INFECTION SYSTEM (SERVER)
--=========================================================
-- Server-side infection data management
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
QCMedServer = QCMedServer or {}

--=========================================================
-- INFECTION DATA OPERATIONS
--=========================================================

-- Handle infection update with validation
local function HandleInfectionUpdate(source, infectionData)
    -- Validate player
    local Player, err = QCMedServer.ValidatePlayer(source)
    if not Player then
        return false, err
    end

    -- Validate infection data structure
    local valid, validErr = QCMedServer.ValidateInfectionData(infectionData)
    if not valid then
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^1[INFECTIONS] Invalid infection data from player %d: %s^7", source, validErr))
        end
        return false, validErr
    end

    -- Save to database
    local success = pcall(function()
        QCMedServer.SaveInfectionData(
            Player.PlayerData.citizenid,
            infectionData
        )
    end)

    if success then
        if Config.WoundSystem.debugging.enabled then
            print(string.format("^2[INFECTIONS] Saved infection data for player %d^7", source))
        end
        return true
    else
        return false, "DATABASE_ERROR"
    end
end

-- Handle infection cure
local function HandleInfectionCure(source, bodyPart, cureType)
    local Player, err = QCMedServer.ValidatePlayer(source)
    if not Player then
        return false, err
    end

    -- Validate body part
    if not Config.BodyParts[bodyPart] then
        return false, "INVALID_BODY_PART"
    end

    -- Check if player has cure item
    local cureConfig = Config.InfectionSystem.cureItems[cureType]
    if not cureConfig then
        return false, "INVALID_CURE_TYPE"
    end

    if not QCMedServer.HasItem(source, cureConfig.itemName) then
        return false, "MISSING_ITEM"
    end

    -- Remove cure item
    if not Player.Functions.RemoveItem(cureConfig.itemName, 1) then
        return false, "FAILED_REMOVE_ITEM"
    end

    -- Trigger client-side cure
    TriggerClientEvent('QC-AdvancedMedic:client:CureInfection', source, bodyPart, cureType)

    -- Log event
    pcall(function()
        QCMedServer.LogMedicalEvent(
            Player.PlayerData.citizenid,
            'infection_cured',
            bodyPart,
            {
                cureType = cureType
            }
        )
    end)

    QCMedServer.NotifySuccess(source,
        locale('cl_menu_infection_cured'),
        string.format("Infection on %s has been cured", bodyPart)
    )

    if Config.WoundSystem.debugging.enabled then
        print(string.format("^2[INFECTIONS] Cured infection on %s for player %d^7", bodyPart, source))
    end

    return true
end

--=========================================================
-- EXPORTS
--=========================================================

QCMedServer.HandleInfectionUpdate = HandleInfectionUpdate
QCMedServer.HandleInfectionCure = HandleInfectionCure

if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
    print("^2[SERVER INFECTIONS] Infection system loaded^7")
end
