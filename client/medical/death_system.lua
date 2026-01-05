--=========================================================
-- QC-ADVANCED MEDIC - DEATH SYSTEM
--=========================================================
-- Handles player death, death camera, respawn, and revive mechanics
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
local sharedWeapons = exports['rsg-core']:GetWeapons()

--=========================================================
-- STATE VARIABLES
--=========================================================

local deathSecondsRemaining = 0
local deathTimerStarted = false
local deathactive = false
local medicsonduty = 0
local medicCalled = false
local Dead = false
local deadcam = nil
local closestRespawn = nil

-- Camera settings
local maxangley = 89.0
local minangley = -89.0
local maxradius = 3.5
local mincoldist = 1.0
local sensedisabled = 0.3
local senseenabled = 0.05
local camheight = 0.5
local looklr = 0x6BC904FC
local lookud = 0x84574AE8
local angley, anglez = 0.0, 0.0

--=========================================================
-- DEATH TIMER
--=========================================================

local function StartDeathTimer()
    deathSecondsRemaining = Config.DeathTimer

    -- Send death screen data to NUI
    SendNUIMessage({
        type = 'show-death-screen',
        data = {
            message = medicsonduty > 0 and "Medical assistance is available" or "No medics on duty",
            seconds = Config.DeathTimer,
            canRespawn = false,
            medicsOnDuty = medicsonduty or 0,
            translations = Config.Strings or {}
        }
    })

    -- Lightweight timer
    CreateThread(function()
        while deathSecondsRemaining > 0 do
            Wait(5000) -- Check every 5 seconds
            deathSecondsRemaining = deathSecondsRemaining - 5

            -- Update NUI occasionally
            if deathSecondsRemaining % 30 == 0 then
                TriggerEvent("QC-AdvancedMedic:client:GetMedicsOnDuty")
                SendNUIMessage({
                    type = 'update-death-timer',
                    data = {
                        timeRemaining = deathSecondsRemaining,
                        medicsOnDuty = medicsonduty or 0
                    }
                })
            end
        end

        -- Timer finished - allow respawn
        SendNUIMessage({
            type = 'death-timer-finished',
            data = { canRespawn = true }
        })
    end)
end

--=========================================================
-- DEATH CAMERA
--=========================================================

local function ProcessNewPosition()
    local sense = IsInputDisabled(0) and sensedisabled or senseenabled
    local mousex = GetDisabledControlNormal(1, looklr) * sense
    local mousey = GetDisabledControlNormal(1, lookud) * sense

    anglez = anglez - mousex
    angley = math.max(minangley, math.min(maxangley, angley + mousey))

    local cosz = math.cos(anglez)
    local sinz = math.sin(anglez)
    local cosy = math.cos(angley)
    local siny = math.sin(angley)

    local pcoords = GetEntityCoords(cache.ped)

    local dirx = cosz * cosy
    local diry = sinz * cosy
    local dirz = siny

    local behindcam = {
        x = pcoords.x + dirx,
        y = pcoords.y + diry,
        z = pcoords.z + dirz
    }

    local rayhandle = StartShapeTestRay(pcoords.x, pcoords.y, pcoords.z + camheight,
                                      behindcam.x, behindcam.y, behindcam.z, -1, cache.ped, 0)
    local _, hitbool, hitcoords = GetShapeTestResult(rayhandle)

    local radius = maxradius
    if hitbool then
        local collisiondist = #(vector3(pcoords.x, pcoords.y, pcoords.z) - hitcoords)
        if collisiondist < mincoldist then
            radius = collisiondist
        end
    end

    return {
        x = pcoords.x + dirx * radius,
        y = pcoords.y + diry * radius,
        z = pcoords.z + dirz * radius
    }
end

local function ProcessCamControls()
    if not Config.DeadMoveCam or not deadcam or not Dead then return end

    local playercoords = GetEntityCoords(cache.ped)
    DisableOnFootFirstPersonViewThisUpdate()
    local newpos = ProcessNewPosition()
    SetCamCoord(deadcam, newpos.x, newpos.y, newpos.z)
    PointCamAtCoord(deadcam, playercoords.x, playercoords.y, playercoords.z)
end

local function StartDeathCam()
    ClearFocus()

    local coords = GetEntityCoords(cache.ped)
    local fov = GetGameplayCamFov()

    if Config.DeadMoveCam then
        -- Free-look camera
        lib.notify({
            title = locale('cl_menu_performance_warning'),
            description = locale('cl_desc_freelook_camera'),
            type = 'warning',
            duration = 5000
        })
        deadcam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", coords, 0, 0, 0, fov)
    else
        -- Simple overhead camera (recommended)
        local camCoords = vector3(coords.x, coords.y - 2.0, coords.z + 5.0)
        deadcam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camCoords.x, camCoords.y, camCoords.z, -45.0, 0.0, 0.0, fov)
        PointCamAtCoord(deadcam, coords.x, coords.y, coords.z)
    end

    SetCamActive(deadcam, true)
    RenderScriptCams(true, true, 1000, true, false)
end

local function EndDeathCam()
    ClearFocus()
    RenderScriptCams(false, false, 0, true, false)
    if deadcam then
        DestroyCam(deadcam, false)
        deadcam = nil
    end
    DestroyAllCams(true)
    angley, anglez = 0.0, 0.0
end

--=========================================================
-- DEATH/RESPAWN LOGIC
--=========================================================

local function SetClosestRespawn()
    local pos = GetEntityCoords(cache.ped, true)
    local current = nil
    local dist = nil

    for k, _ in pairs(Config.RespawnLocations) do
        local dest = vector3(Config.RespawnLocations[k].coords.x, Config.RespawnLocations[k].coords.y, Config.RespawnLocations[k].coords.z)
        local dist2 = #(pos - dest)

        if current then
            if dist2 < dist then
                current = k
                dist = dist2
            end
        else
            dist = dist2
            current = k
        end
    end

    closestRespawn = current
end

local function LogDeath()
    local player = PlayerId()
    local ped = PlayerPedId()
    local killer, killerWeapon = NetworkGetEntityKillerOfPlayer(player)

    if killer == ped or killer == -1 then return end

    local killerId = NetworkGetPlayerIndexFromPed(killer)
    local killerName = GetPlayerName(killerId) .. " ("..GetPlayerServerId(killerId)..")"
    local weaponLabel = 'Unknown'
    local weaponName = 'Unknown'
    local weaponItem = sharedWeapons[killerWeapon]
    if weaponItem then
        weaponLabel = weaponItem.label
        weaponName = weaponItem.name
    end

    local playerid = GetPlayerServerId(player)
    local playername = GetPlayerName(player)
    local msgDiscordA = playername..' ('..playerid..') '.. locale('cl_death_log_title')
    local msgDiscordB = killerName..' '.. locale('cl_death_log_message')..' '..playername.. ' '..locale('cl_death_log_message_b')..' **'..weaponLabel..'** ('..weaponName..')'
    TriggerServerEvent('rsg-log:server:CreateLog', 'death', msgDiscordA, 'red', msgDiscordB)
end

--=========================================================
-- EVENT HANDLERS
--=========================================================

-- Death camera management
AddEventHandler('QC-AdvancedMedic:client:DeathCam', function()
    CreateThread(function()
        while true do
            Wait(1000)

            if not Dead and deathactive then
                Dead = true
                StartDeathCam()
            elseif Dead and not deathactive then
                Dead = false
                EndDeathCam()
            end

            if deathSecondsRemaining <= 0 and not deathactive then
                Dead = false
                EndDeathCam()
                return
            end
        end
    end)

    CreateThread(function()
        while true do
            local waitTime = Config.DeadMoveCam and 16 or 1000
            Wait(waitTime)

            if deathactive and not deadcam then
                StartDeathCam()
            elseif deadcam and Dead and Config.DeadMoveCam then
                ProcessCamControls()
            end

            if deathSecondsRemaining <= 0 and not deathactive then return end
        end
    end)
end)

-- Get medics on duty count
AddEventHandler('QC-AdvancedMedic:client:GetMedicsOnDuty', function()
    RSGCore.Functions.TriggerCallback('QC-AdvancedMedic:server:getmedics', function(mediccount)
        medicsonduty = mediccount
    end)
end)

-- Player Revive After Pressing [E]
AddEventHandler('QC-AdvancedMedic:client:revive', function()
    SetClosestRespawn()

    -- Hide death screen NUI
    SendNUIMessage({ type = 'hide-death-screen' })

    local respawnCoords = Config.RespawnLocations[closestRespawn].coords
    SetEntityCoords(cache.ped, respawnCoords.x, respawnCoords.y, respawnCoords.z, false, false, false, false)
    SetEntityHeading(cache.ped, Config.RespawnLocations[closestRespawn].heading or 0.0)

    -- Revive player
    NetworkResurrectLocalPlayer(respawnCoords.x, respawnCoords.y, respawnCoords.z, Config.RespawnLocations[closestRespawn].heading or 0.0, true, false)
    SetEntityHealth(cache.ped, Config.MaxHealth or 400)
    ClearPedTasksImmediately(cache.ped)

    -- End death state
    deathactive = false
    deathTimerStarted = false
    deathSecondsRemaining = 0
    Dead = false
    EndDeathCam()

    -- Trigger server event
    TriggerServerEvent('QC-AdvancedMedic:server:deathactions')

    lib.notify({
        title = locale('cl_menu_respawned'),
        description = locale('cl_desc_respawned'),
        type = 'success',
        duration = 5000
    })
end)

-- Player death event
RegisterNetEvent('QC-AdvancedMedic:client:playerDied')
AddEventHandler('QC-AdvancedMedic:client:playerDied', function()
    deathactive = true
    LogDeath()
    StartDeathTimer()
    TriggerEvent('QC-AdvancedMedic:client:DeathCam')
end)

-- Admin revive
RegisterNetEvent('QC-AdvancedMedic:client:playerRevive')
AddEventHandler('QC-AdvancedMedic:client:playerRevive', function()
    -- End death state
    deathactive = false
    deathTimerStarted = false
    deathSecondsRemaining = 0
    Dead = false
    EndDeathCam()

    -- Hide death screen
    SendNUIMessage({ type = 'hide-death-screen' })

    -- Revive player
    NetworkResurrectLocalPlayer(GetEntityCoords(cache.ped), GetEntityHeading(cache.ped), true, false)
    SetEntityHealth(cache.ped, Config.MaxHealth or 400)
    ClearPedTasksImmediately(cache.ped)

    lib.notify({
        title = locale('cl_menu_revived'),
        description = locale('cl_desc_revived'),
        type = 'success',
        duration = 5000
    })
end)

--=========================================================
-- EXPORTS
--=========================================================

exports('IsPlayerDead', function() return deathactive end)
exports('GetDeathTimeRemaining', function() return deathSecondsRemaining end)
exports('GetClosestRespawn', function() return closestRespawn end)
