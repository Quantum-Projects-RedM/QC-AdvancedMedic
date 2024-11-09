local RSGCore = exports['rsg-core']:GetCoreObject()
local blipEntries = {}
local transG = Config.DeathTimer
lib.locale()

------------------------
--- FUNCTIONS 
------------------------
-- Get Closest Player
local GetClosestPlayer = function()
    local coords = GetEntityCoords(cache.ped)
    local closestDistance = -1
    local closestPlayer = -1
    local closestPlayers = RSGCore.Functions.GetPlayersFromCoords()

    for i = 1, #closestPlayers, 1 do
        if closestPlayers[i] ~= PlayerId() then
            local ped = GetPlayerPed(closestPlayers[i])
            local pos = GetEntityCoords(ped)
            local distance = #(pos - coords)

            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = closestPlayers[i]
                closestDistance = distance
            end
        end
    end

    return closestPlayer, closestDistance
end

------------------------
--- EVENTS
------------------------
-- Toggle On-Duty
AddEventHandler('qc-AdvancedMedic:client:ToggleDuty', function()
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        local PlayerJob = PlayerData.job

        if PlayerJob.name ~= Config.JobRequired then
            lib.notify({ title = locale('cl_not_medic'), type = 'error', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake', duration = 7000 })
            return
        end

        TriggerServerEvent("RSGCore:ToggleDuty")
    end)
end)

-- Medic Revive Player
AddEventHandler('qc-AdvancedMedic:client:RevivePlayer', function()
    local hasItem = RSGCore.Functions.HasItem('firstaid', 1)
    if not hasItem then
        lib.notify({ title = locale('cl_need_kit'), type = 'error', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake',  duration = 7000  })
        return
    end

    local player, distance = GetClosestPlayer()
    if player == -1 or distance >= 5.0 then
        lib.notify({ title = locale('cl_player_nearby'), type = 'error', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake', duration = 7000 })
        return
    end

    local playerId = GetPlayerServerId(player)
    local tped = GetPlayerPed(GetPlayerFromServerId(playerId))

    TaskTurnPedToFaceEntity(cache.ped, tped, -1)

    Wait(3000)

    FreezeEntityPosition(cache.ped, true)
    TaskStartScenarioInPlace(cache.ped, `WORLD_HUMAN_CROUCH_INSPECT`, -1, true, false, false, false)

    Wait(5000)

    ExecuteCommand('me Reviving')

    lib.progressBar({
        duration = Config.MedicReviveTime,
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disableControl = true,
        disable = {
            move = true,
            mouse = false,
        },
        label = locale('cl_reviving'),
    })

    ClearPedTasks(cache.ped)
    FreezeEntityPosition(cache.ped, false)
    TriggerServerEvent('qc-AdvancedMedic:server:RevivePlayer', playerId)
    transG = 0

end)

-- Medic Treat Wounds
AddEventHandler('qc-AdvancedMedic:client:TreatWounds', function()
    local hasItem = RSGCore.Functions.HasItem('bandage', 1)
    if not hasItem then
        lib.notify({ title = locale('cl_need_bandage'), type = 'error', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake', duration = 7000 })
        return
    end

    local player, distance = GetClosestPlayer()
    if player == -1 or distance >= 5.0 then
        lib.notify({ title = locale('cl_player_nearby'), type = 'error', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake', duration = 7000 })
        return
    end

    local ped = PlayerPedId()
    local playerId = GetPlayerServerId(player)
    local tped = GetPlayerPed(GetPlayerFromServerId(playerId))

    TaskTurnPedToFaceEntity(cache.ped, tped, -1)

    Wait(3000)

    FreezeEntityPosition(cache.ped, true)
    TaskStartScenarioInPlace(cache.ped, `WORLD_HUMAN_CROUCH_INSPECT`, -1, true, false, false, false)

    Wait(5000)

    ExecuteCommand('me Treating Wounds')

    lib.progressBar({
        duration = Config.MedicTreatTime,
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disableControl = true,
        disable = {
            move = true,
            mouse = false,
        },
        label = locale('cl_treating'),
    })

    ClearPedTasks(cache.ped)
    FreezeEntityPosition(cache.ped, false)
    TriggerServerEvent('qc-AdvancedMedic:server:TreatWounds', playerId)
    transG = 0

end)

-- Medic Treat Wounds
RegisterNetEvent('qc-AdvancedMedic:client:HealInjuries', function()
    SetAttributeCoreValue(cache.ped, 0, 100)
    SetAttributeCoreValue(cache.ped, 1, 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "hunger", RSGCore.Functions.GetPlayerData().metadata["hunger"] + 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "thirst", RSGCore.Functions.GetPlayerData().metadata["thirst"] + 100)
    ClearPedBloodDamage(cache.ped)
end)

-- Medic Alert
RegisterNetEvent('qc-AdvancedMedic:client:medicAlert', function(coords, text)
    lib.notify({ title = locale('cl_info'), description = text, type = 'info', duration = 7000 })

    local blip = BlipAddForCoords(1664425300, coords.x, coords.y, coords.z)
    local blip2 = BlipAddForCoords(1664425300, coords.x, coords.y, coords.z)

    SetBlipSprite(blip, 1109348405)
    SetBlipSprite(blip2, -184692826)
    BlipAddModifier(blip, GetHashKey('BLIP_MODIFIER_AREA_PULSE'))
    BlipAddModifier(blip2, GetHashKey('BLIP_MODIFIER_AREA_PULSE'))
    SetBlipScale(blip, 0.8)
    SetBlipScale(blip2, 2.0)
    SetBlipName(blip, text)
    SetBlipName(blip2, text)

    blipEntries[#blipEntries + 1] = {coords = coords, handle = blip}
    blipEntries[#blipEntries + 1] = {coords = coords, handle = blip2}

    -- Add GPS Route

    if Config.AddGPSRoute then
        StartGpsMultiRoute(`COLOR_GREEN`, true, true)
        AddPointToGpsMultiRoute(coords)
        SetGpsMultiRouteRender(true)
    end

    CreateThread(function ()
        while transG ~= 0 do
            Wait(180 * 4)

            local pcoord = GetEntityCoords(cache.ped)
            local distance = #(coords - pcoord)
            transG = transG - 1

            if Config.Debug then
                print(locale('cl_player_blip') .. tostring(distance) .. locale('cl_m'))
            end

            if transG <= 0 or distance < 5.0 then
                for i = 1, #blipEntries do
                    local blips = blipEntries[i]
                    local bcoords = blips.coords

                    if coords == bcoords then
                        if Config.Debug then
                            print('')
                            print(locale('cl_blip')..tostring(bcoords))
                            print(locale('cl_blip_remove')..tostring(blipEntries[i].handle))
                            print('')
                        end

                        RemoveBlip(blipEntries[i].handle)
                    end
                end

                transG = Config.DeathTimer

                if Config.AddGPSRoute then
                    ClearGpsMultiRoute(coords)
                end

                return
            end
        end
    end)
end)

-- Cleanup
local resource = GetCurrentResourceName()
AddEventHandler("onResourceStop", function(resourceName)
    if resource ~= resourceName then return end

    ClearGpsMultiRoute(coords)

    for i = 1, #blipEntries do
        if blipEntries[i].handle then
            RemoveBlip(blipEntries[i].handle)
        end
    end
end)
