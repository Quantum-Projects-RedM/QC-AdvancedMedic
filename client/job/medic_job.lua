--=========================================================
-- QC-ADVANCED MEDIC - MEDIC JOB MECHANICS
--=========================================================
-- Job duties, player revive, treatment, and medic alerts
-- Extracted from job_system.lua for better organization
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

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

    return exports['QC-AdvancedMedic']:IsMedicJob(Player.job.name)
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

exports('GetClosestPlayer', GetClosestPlayer)
exports('IsPlayerMedic', IsPlayerMedic)

if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
    print("^2[MEDIC JOB] Job mechanics loaded^7")
end
