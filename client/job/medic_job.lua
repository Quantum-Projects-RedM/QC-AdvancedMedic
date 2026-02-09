--=========================================================
-- QC-ADVANCED MEDIC - MEDIC JOB MECHANICS
--=========================================================
-- Job duties, player revive, treatment, and medic alerts
-- Extracted from job_system.lua for better organization
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
QCMed = QCMed or {}

--=========================================================
-- HELPER FUNCTIONS
--=========================================================

-- Get closest player to the medic
local function GetClosestPlayer()
    local players = GetActivePlayers()
    local closestDistance = -1
    local closestPlayer = -1
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    for i = 1, #players do
        local target = GetPlayerPed(players[i])
        if target ~= playerPed then
            local targetCoords = GetEntityCoords(target)
            local distance = #(targetCoords - playerCoords)

            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = players[i]
                closestDistance = distance
            end
        end
    end

    return closestPlayer, closestDistance
end

-- Check if player has medic job
local function IsPlayerMedic()
    local Player = RSGCore.Functions.GetPlayerData()
    if not Player or not Player.job then return false end

    return QCMed.IsMedicJob(Player.job.name)
end

--=========================================================
-- DUTY TOGGLE
--=========================================================

-- Toggle medic duty on/off
RegisterNetEvent('QC-AdvancedMedic:client:ToggleDuty', function()
    if not IsPlayerMedic() then
        lib.notify({
            title = locale('cl_menu_not_medic'),
            description = locale('cl_desc_not_medic_job'),
            type = 'error',
            duration = 5000
        })
        return
    end

    TriggerServerEvent('RSGCore:ToggleDuty')
end)

--=========================================================
-- PLAYER REVIVE
--=========================================================

-- Revive nearest player
RegisterNetEvent('QC-AdvancedMedic:client:RevivePlayer', function()
    if not IsPlayerMedic() then
        lib.notify({
            title = locale('cl_menu_not_medic'),
            description = locale('cl_desc_not_medic_job'),
            type = 'error',
            duration = 5000
        })
        return
    end

    local closestPlayer, distance = GetClosestPlayer()
    if closestPlayer == -1 or distance > 3.0 then
        lib.notify({
            title = locale('cl_menu_no_players_nearby'),
            description = locale('cl_desc_no_player_within_range'),
            type = 'error',
            duration = 5000
        })
        return
    end

    local targetPed = GetPlayerPed(closestPlayer)
    local targetServerId = GetPlayerServerId(closestPlayer)

    -- Start revive animation
    local playerPed = PlayerPedId()
    TaskStartScenarioInPlace(playerPed, `WORLD_HUMAN_CROUCH_INSPECT`, -1, true, false, false, false)

    if lib.progressBar({
        duration = 10000,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disableControl = true,
        disable = { move = true, mouse = true },
        label = locale('cl_progress_reviving_player'),
        anim = {
            dict = 'mini_games@story@mob4@heal_jules@bandage@arthur',
            clip = 'bandage_fast',
            flag = 1,
        },
    }) then
        ClearPedTasks(playerPed)

        -- Trigger server to revive player
        TriggerServerEvent('QC-AdvancedMedic:server:RevivePlayer', targetServerId)

        lib.notify({
            title = locale('cl_menu_player_revived'),
            description = locale('cl_desc_player_revived'),
            type = 'success',
            duration = 5000
        })
    else
        ClearPedTasks(playerPed)
        lib.notify({
            title = locale('cl_menu_cancelled'),
            description = locale('cl_desc_revive_cancelled'),
            type = 'error',
            duration = 3000
        })
    end
end)

--=========================================================
-- TREAT WOUNDS
--=========================================================

-- Treat wounds on nearest player
RegisterNetEvent('QC-AdvancedMedic:client:TreatWounds', function()
    if not IsPlayerMedic() then
        lib.notify({
            title = locale('cl_menu_not_medic'),
            description = locale('cl_desc_not_medic_job'),
            type = 'error',
            duration = 5000
        })
        return
    end

    local closestPlayer, distance = GetClosestPlayer()
    if closestPlayer == -1 or distance > 3.0 then
        lib.notify({
            title = locale('cl_menu_no_players_nearby'),
            description = locale('cl_desc_no_player_within_range'),
            type = 'error',
            duration = 5000
        })
        return
    end

    local targetServerId = GetPlayerServerId(closestPlayer)

    -- Open treatment menu (uses existing inspection system)
    TriggerEvent('QC-AdvancedMedic:client:InspectPlayer', targetServerId)
end)

--=========================================================
-- HEAL INJURIES (Full Heal)
--=========================================================

-- Fully heal nearest player's injuries
RegisterNetEvent('QC-AdvancedMedic:client:HealInjuries', function()
    if not IsPlayerMedic() then
        lib.notify({
            title = locale('cl_menu_not_medic'),
            description = locale('cl_desc_not_medic_job'),
            type = 'error',
            duration = 5000
        })
        return
    end

    local closestPlayer, distance = GetClosestPlayer()
    if closestPlayer == -1 or distance > 3.0 then
        lib.notify({
            title = locale('cl_menu_no_players_nearby'),
            description = locale('cl_desc_no_player_within_range'),
            type = 'error',
            duration = 5000
        })
        return
    end

    local targetServerId = GetPlayerServerId(closestPlayer)
    local playerPed = PlayerPedId()

    -- Start healing animation
    TaskStartScenarioInPlace(playerPed, `WORLD_HUMAN_CROUCH_INSPECT`, -1, true, false, false, false)

    if lib.progressBar({
        duration = 8000,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disableControl = true,
        disable = { move = true, mouse = true },
        label = locale('cl_progress_healing_injuries'),
        anim = {
            dict = 'mini_games@story@mob4@heal_jules@bandage@arthur',
            clip = 'bandage_fast',
            flag = 1,
        },
    }) then
        ClearPedTasks(playerPed)

        -- Trigger server to heal player
        TriggerServerEvent('QC-AdvancedMedic:server:HealInjuries', targetServerId)

        lib.notify({
            title = locale('cl_menu_injuries_healed'),
            description = locale('cl_desc_injuries_healed'),
            type = 'success',
            duration = 5000
        })
    else
        ClearPedTasks(playerPed)
        lib.notify({
            title = locale('cl_menu_cancelled'),
            description = locale('cl_desc_healing_cancelled'),
            type = 'error',
            duration = 3000
        })
    end
end)

--=========================================================
-- INSPECT PLAYER
--=========================================================

RegisterNetEvent('QC-AdvancedMedic:client:InspectPlayer')
AddEventHandler('QC-AdvancedMedic:client:InspectPlayer', function(targetServerId)
    if not IsPlayerMedic() then
        lib.notify({ title = locale('cl_menu_not_medic'), description = locale('cl_desc_not_medic_job'), type = 'error', duration = 5000 })
        return
    end

    local closestPlayer, distance
    if not targetServerId then
        closestPlayer, distance = GetClosestPlayer()
        if closestPlayer == -1 or distance > 3.0 then
            lib.notify({ title = locale('cl_menu_no_players_nearby'), description = locale('cl_desc_no_player_within_range'), type = 'error', duration = 5000 })
            return
        end
        targetServerId = GetPlayerServerId(closestPlayer)
    end

    local playerPed = PlayerPedId()
    TaskStartScenarioInPlace(playerPed, `WORLD_HUMAN_CROUCH_INSPECT`, -1, true, false, false, false)

    if lib.progressBar({
        duration = 5000,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disableControl = true,
        disable = { move = true, mouse = true },
        label = "Inspecting patient...",
    }) then
        ClearPedTasks(playerPed)
        TriggerServerEvent('QC-AdvancedMedic:server:RequestWoundData', targetServerId)
    else
        ClearPedTasks(playerPed)
        lib.notify({ title = locale('cl_menu_cancelled'), description = "Inspection cancelled", type = 'error', duration = 3000 })
    end
end)

-- Receive wound data from server and open NUI inspection panel
RegisterNetEvent('QC-AdvancedMedic:client:ReceiveWoundData')
AddEventHandler('QC-AdvancedMedic:client:ReceiveWoundData', function(targetPlayerId, woundData)
    local bleedLevel = tonumber(woundData.bleedingLevel) or 0
    local changesNeeded = tonumber(woundData.bandageChangesNeeded) or 0
    local changesApplied = tonumber(woundData.bandageChangesApplied) or 0

    -- Build wound entry with all fields the NUI expects
    local woundEntry = {
        bleedingLevel = bleedLevel,
        painLevel = math.min(bleedLevel * 10, 100),
        severity = math.min(bleedLevel * 10, 100),
        bleeding = bleedLevel * 10,
        woundType = woundData.lastWoundSource or 'unknown',
        bandageChangesNeeded = changesNeeded,
        bandageChangesApplied = changesApplied,
    }

    -- Map global wound data to body parts using keys that match React mapFrontendToBackend()
    -- React mapping: upbody→UPPER_BODY, lowbody→LOWER_BODY, larm→LARM, rarm→RARM, etc.
    local wounds = {}
    if bleedLevel > 0 or changesNeeded > 0 then
        -- Always show on upper body (torso - primary wound area)
        wounds['UPPER_BODY'] = woundEntry

        -- Spread to additional body parts based on wound severity
        if bleedLevel >= 4 then
            wounds['LOWER_BODY'] = woundEntry
        end
        if bleedLevel >= 6 then
            wounds['LARM'] = woundEntry
            wounds['RARM'] = woundEntry
        end
        if bleedLevel >= 8 then
            wounds['LLEG'] = woundEntry
            wounds['RLEG'] = woundEntry
        end
    end

    local inspectionData = {
        playerName = "Patient #" .. targetPlayerId,
        playerId = tostring(targetPlayerId),
        playerSource = targetPlayerId,
        bloodLevel = math.max(0, 100 - (bleedLevel * 10)),
        isBleeding = bleedLevel > 0,
        wounds = wounds,
        treatments = {},
        infections = {},
        bandages = {},
        healthData = {},
        description = woundData.lastWoundSource or "No visible injuries",
    }

    print(string.format("^3[INSPECT CLIENT] Bleeding: %.1f, Wounds keys: %s^7",
        bleedLevel, json.encode(wounds)))

    TriggerEvent('QC-AdvancedMedic:client:ShowInspectionPanel', inspectionData)
end)

--=========================================================
-- MEDIC ALERT
--=========================================================

-- Send medic alert to all medics
RegisterNetEvent('QC-AdvancedMedic:client:medicAlert', function(coords, message)
    if not IsPlayerMedic() then return end

    -- Create blip at alert location
    local blip = BlipAddForCoords(1664425300, coords.x, coords.y, coords.z)
    SetBlipSprite(blip, GetHashKey('blip_ambient_speech'), true)
    SetBlipScale(blip, 0.2)
    SetBlipName(blip, 'Medical Emergency')

    -- Show notification
    lib.notify({
        title = locale('cl_menu_medical_alert'),
        description = message or locale('cl_desc_medical_emergency'),
        type = 'inform',
        duration = 10000
    })

    -- Set GPS route if configured
    if Config.AddGPSRoute then
        ClearGpsMultiRoute()
        StartGpsMultiRoute(6, true, true)
        AddPointToGpsMultiRoute(coords.x, coords.y, coords.z)
        SetGpsMultiRouteRender(true)
    end

    -- Remove blip after 5 minutes
    CreateThread(function()
        Wait(300000) -- 5 minutes
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)
end)

--=========================================================
-- EXPORTS
--=========================================================

QCMed.GetClosestPlayer = GetClosestPlayer
QCMed.IsPlayerMedic = IsPlayerMedic

if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
    print("^2[MEDIC JOB] Job mechanics loaded^7")
end
