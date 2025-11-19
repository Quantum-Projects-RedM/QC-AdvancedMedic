local RSGCore = exports['rsg-core']:GetCoreObject()
local sharedWeapons = exports['rsg-core']:GetWeapons()
local createdEntries = {}
local isLoggedIn = false
local deathSecondsRemaining = 0
local deathTimerStarted = false
local deathactive = false
local mediclocation = nil
local medicsonduty = 0
local healthset = false
local nuiFocusEnabled = false
local closestRespawn = nil
local medicCalled = false
local Dead = false
local deadcam = nil
local isBusy = false
local targetBodyPartOverride = nil  -- Used by /usebandage command to specify exact body part


-- Medical data globals (remove duplicate declaration if exists)
-- Note: ActiveTreatments is declared in treatment_system.lua

-- Event to receive treatments data from server
RegisterNetEvent('QC-AdvancedMedic:client:LoadTreatments')
AddEventHandler('QC-AdvancedMedic:client:LoadTreatments', function(treatments)
    if treatments then
        ActiveTreatments = treatments
        
        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
            print("^2[TREATMENTS] Received treatments data from server^7")
            local treatmentCount = 0
            for _ in pairs(ActiveTreatments) do treatmentCount = treatmentCount + 1 end
            print("^3[TREATMENTS] Loaded " .. treatmentCount .. " active treatments^7")
            
            for bodyPart, treatment in pairs(ActiveTreatments) do
                print(string.format("^3[TREATMENTS] - %s: %s (%s) applied at %s^7", 
                    bodyPart, 
                    treatment.treatmentType or "unknown", 
                    treatment.itemType or "unknown",
                    treatment.appliedTime or "unknown"))
            end
        end
        
        -- Force NUI update when treatments are loaded
        CreateThread(function()
            Wait(100) -- Small delay to ensure data is processed
            
            -- Get current medical data
            local updatedBodyPartHealth = GetBodyPartHealthData()
            local updatedWounds = PlayerWounds or {}
            local updatedTreatments = {}
            local updatedInfections = PlayerInfections or {}
            
            -- Convert ActiveTreatments to array for NUI
            if ActiveTreatments then
                for bodyPartKey, treatment in pairs(ActiveTreatments) do
                    table.insert(updatedTreatments, {
                        bodyPart = bodyPartKey,
                        type = treatment.treatmentType,
                        itemType = treatment.itemType,
                        appliedTime = treatment.appliedTime,
                        effectiveness = treatment.effectiveness,
                        appliedBy = treatment.appliedBy
                    })
                end
            end
            
            -- Update NUI with fresh data
            SendNUIMessage({
                type = 'update-medical-data',
                data = {
                    wounds = updatedWounds,
                    treatments = updatedTreatments,
                    infections = updatedInfections,
                    bodyPartHealth = updatedBodyPartHealth
                }
            })
            
            if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                print("^2[TREATMENTS] Forced NUI update with " .. #updatedTreatments .. " treatments^7")
            end
        end)
    else
        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
            print("^1[TREATMENTS] Received nil treatments data from server^7")
        end
    end
end)

-- Event to receive wounds data from server
RegisterNetEvent('QC-AdvancedMedic:client:LoadWounds')
AddEventHandler('QC-AdvancedMedic:client:LoadWounds', function(wounds)
    if wounds then
        PlayerWounds = wounds
        
        -- Wound loading summary handled in wound_system.lua
    end
end)

-- Event to receive infections data from server
RegisterNetEvent('QC-AdvancedMedic:client:LoadInfections')
AddEventHandler('QC-AdvancedMedic:client:LoadInfections', function(infections)
    if infections then
        PlayerInfections = infections
        
        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
            print("^2[INFECTIONS] Received infections data from server^7")
        end
    end
end)

---------------------------------------------------------------------
-- death timer
---------------------------------------------------------------------
local deathTimer = function()
    deathSecondsRemaining = Config.DeathTimer

    -- Send death screen data to NUI once instead of heavy loops
    SendNUIMessage({
        type = 'show-death-screen',
        data = {
            message = medicsonduty > 0 and "Medical assistance is available" or "No medics on duty",
            seconds = Config.DeathTimer,
            canRespawn = false,
            medicsOnDuty = medicsonduty or 0,
            translations = Config.Strings or {}  -- Send all locale strings to NUI
        }
    })
    
    -- Lightweight timer without heavy server events every second
    CreateThread(function()
        while deathSecondsRemaining > 0 do
            Wait(5000) -- Check every 5 seconds instead of every second
            deathSecondsRemaining = deathSecondsRemaining - 5
            
            -- Update NUI occasionally instead of server events
            if deathSecondsRemaining % 30 == 0 then -- Every 30 seconds
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

---------------------------------------------------------------------
-- drawtext for countdown
---------------------------------------------------------------------
local DrawTxt = function(str, x, y, w, h, enableShadow, col1, col2, col3, a, centre)
    local string = CreateVarString(10, "LITERAL_STRING", str)

    SetTextScale(w, h)
    SetTextColor(math.floor(col1), math.floor(col2), math.floor(col3), math.floor(a))
    SetTextCentre(centre)

    if enableShadow then
        SetTextDropshadow(1, 0, 0, 0, 255)
    end

    DisplayText(string, x, y)
end

---------------------------------------------------------------------
-- start death cam
---------------------------------------------------------------------
local StartDeathCam = function()
    ClearFocus()

    local coords = GetEntityCoords(cache.ped)
    local fov = GetGameplayCamFov()

    if Config.DeadMoveCam then
        -- Performance warning for free-look camera
        lib.notify({
            title = locale('cl_menu_performance_warning'),
            description = locale('cl_desc_freelook_camera'),
            type = 'warning',
            duration = 5000
        })
        print('^3[QC-AdvancedMedic] WARNING: Free-look death camera enabled - higher performance impact^7')
        
        -- Create free-look camera at player position
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

---------------------------------------------------------------------
-- optimized free-look camera system
---------------------------------------------------------------------
local maxangley = 89.0
local minangley = -89.0
local maxradius = 3.5
local mincoldist = 1.0
local sensedisabled = 0.3 -- Much slower when input disabled
local senseenabled = 0.05  -- Much slower when input enabled
local camheight = 0.5
local looklr = 0x6BC904FC
local lookud = 0x84574AE8
local angley, anglez = 0.0, 0.0

local ProcessNewPosition = function()
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

local ProcessCamControls = function()
    if not Config.DeadMoveCam or not deadcam or not Dead then return end
    
    local playercoords = GetEntityCoords(cache.ped)
    DisableOnFootFirstPersonViewThisUpdate()
    local newpos = ProcessNewPosition()
    SetCamCoord(deadcam, newpos.x, newpos.y, newpos.z)
    PointCamAtCoord(deadcam, playercoords.x, playercoords.y, playercoords.z)
end

---------------------------------------------------------------------
-- end death cam
---------------------------------------------------------------------
local EndDeathCam = function()
    ClearFocus()
    RenderScriptCams(false, false, 0, true, false)
    if deadcam then
        DestroyCam(deadcam, false)
        deadcam = nil
    end
    DestroyAllCams(true)
    angley, anglez = 0.0, 0.0 -- Reset camera angles
end

---------------------------------------------------------------------
-- dealth log
---------------------------------------------------------------------
local deathLog = function()
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

---------------------------------------------------------------------
-- medic call delay
---------------------------------------------------------------------
local MedicCalled = function()
    local delay = Config.MedicCallDelay * 1000
    CreateThread(function()
        while true do
            Wait(delay)
            medicCalled = false
            return
        end
    end)
end

---------------------------------------------------------------------
-- set closest respawn
---------------------------------------------------------------------
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

    if current ~= closestRespawn then
        closestRespawn = current
    end
end

---------------------------------------------------------------------
-- Dynamic prompts and blips (only show for correct job)
---------------------------------------------------------------------
local activePrompts = {}
local activeBlips = {}

-- Function to create prompts for player's current job
local function UpdateMedicPrompts()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local playerJob = PlayerData.job.name
    
    -- Clear existing prompts and blips
    for _, prompt in pairs(activePrompts) do
        exports['rsg-core']:removePrompt(prompt)
    end
    for _, blip in pairs(activeBlips) do
        RemoveBlip(blip)
    end
    activePrompts = {}
    activeBlips = {}
    
    -- Create prompts only for locations matching player's job
    for i = 1, #Config.MedicJobLocations do
        local loc = Config.MedicJobLocations[i]
        
        -- Only create prompt if player has the correct job for this location
        if playerJob == loc.job then
            local prompt = exports['rsg-core']:createPrompt(loc.prompt, loc.coords, RSGCore.Shared.Keybinds['J'], locale('cl_open') .. loc.name,
            {
                type = 'client',
                event = 'QC-AdvancedMedic:client:mainmenu',
                args = {loc.prompt, loc.name}
            })
            
            activePrompts[#activePrompts + 1] = prompt
            createdEntries[#createdEntries + 1] = {type = "PROMPT", handle = loc.prompt}

            if loc.showblip then
                local MedicBlip = BlipAddForCoords(1664425300, loc.coords)
                SetBlipSprite(MedicBlip, GetHashKey(Config.Blip.Sprite), true)
                SetBlipScale(MedicBlip, Config.Blip.Scale)
                SetBlipName(MedicBlip, Config.Blip.Name)
                activeBlips[#activeBlips + 1] = MedicBlip
                createdEntries[#createdEntries + 1] = {type = "BLIP", handle = MedicBlip}
            end
        end
    end
end

-- Initial prompt setup
CreateThread(function()
    -- Wait for player data to be available
    while not RSGCore.Functions.GetPlayerData().job do
        Wait(1000)
    end
    
    UpdateMedicPrompts()
end)

-- Update prompts when job changes
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded')
AddEventHandler('RSGCore:Client:OnPlayerLoaded', function()
    Wait(2000) -- Wait for job data to be fully loaded
    UpdateMedicPrompts()
end)

RegisterNetEvent('RSGCore:Client:OnJobUpdate')
AddEventHandler('RSGCore:Client:OnJobUpdate', function(JobInfo)
    Wait(1000) -- Small delay to ensure job data is updated
    UpdateMedicPrompts()
end)

---------------------------------------------------------------------
-- player death loop
---------------------------------------------------------------------
CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state['isLoggedIn']
    while true do
        local health = GetEntityHealth(cache.ped)
        if health == 0 and deathactive == false then
            exports.spawnmanager:setAutoSpawn(false)
            deathTimerStarted = true
            deathTimer()
            deathLog()
            deathactive = true
            TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", true)
            TriggerEvent('QC-AdvancedMedic:client:DeathCam')
        end
        Wait(1000)
    end
end)

---------------------------------------------------------------------
-- player update health loop
---------------------------------------------------------------------
CreateThread(function()
    local lasthealth = 0
    repeat Wait(1000) until LocalPlayer.state['isLoggedIn']
    while true do
        local health = GetEntityHealth(cache.ped)
        
        -- PERFORMANCE FIX: Don't send server events when dead (saves network traffic)
        if not deathactive and health ~= lasthealth then
            TriggerServerEvent('QC-AdvancedMedic:server:SetHealth', health)
            lasthealth = health
            print('^2[QC-AdvancedMedic] Sent health update to server: ' .. tostring(health) .. '^7')
        end
        
        Wait(deathactive and 5000 or 1000) -- Check every 5 seconds when dead, every 1 second when alive
    end
end)

---------------------------------------------------------------------
-- display respawn message and countdown
---------------------------------------------------------------------
CreateThread(function()
    while true do
        local t = 1000

        if deathactive then
            t = 16 -- Need responsive right-click detection but not too aggressive

            -- Right-click to enable NUI focus for button interaction
            if not nuiFocusEnabled and IsControlJustReleased(0, 0xF84FA74F) then -- Right mouse button hash
                nuiFocusEnabled = true
                SetNuiFocus(nuiFocusEnabled, nuiFocusEnabled)
                
                lib.notify({
                    title = locale('cl_menu_nui_focus'),
                    description = locale('cl_desc_mouse_enabled'),
                    type = 'inform',
                    duration = 3000
                })
            end

            -- All UI functionality moved to NUI - no more DrawText needed
        end

        if Config.Debug then
            print('deathTimerStarted: '..tostring(deathTimerStarted))
            print('deathSecondsRemaining: '..tostring(deathSecondsRemaining))
            print('medicsonduty: '..tostring(medicsonduty))
        end

        Wait(t)
    end
end)

-------------------------------------------------------- EVENTS --------------------------------------------------------

---------------------------------------------------------------------
-- Helper function to check if player has the correct job for this specific location
local function CanAccessLocation(location)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local playerJob = PlayerData.job.name
    
    -- Find the specific job required for this location
    for _, locationData in pairs(Config.MedicJobLocations) do
        if locationData.prompt == location or locationData.name == location then
            return playerJob == locationData.job
        end
    end
    return false
end

-- medic menu
---------------------------------------------------------------------
AddEventHandler('QC-AdvancedMedic:client:mainmenu', function(location, name)
    if not CanAccessLocation(location) then
        lib.notify({ title = locale('cl_access_denied'), description = locale('cl_no_access_facility'), type = 'error', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake', duration = 7000 })
        return
    end

    mediclocation = location

    -- Get player job info for role-based menu options
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local job = PlayerData.job
    local grade = job.grade.level
    local isBoss = job.grade.isboss
    local isPharmacist = (grade >= 2) -- Pharmacist role and above
    
    local menuOptions = {
        -- 1. Toggle Duty (always first)
        {   title = locale('cl_duty'),
            icon = 'fa-solid fa-shield-heart',
            description = locale('cl_desc_duty_management'),
            event = 'QC-AdvancedMedic:client:OpenDutyMenu',
            arrow = true
        },
        -- 2. Medical Storage (always available)
        {   title = locale('cl_medical_storage'),
            icon = 'fa-solid fa-box-open',
            description = locale('cl_medical_storage_desc') or 'Access medical equipment storage',
            event = 'QC-AdvancedMedic:client:storage',
            arrow = true
        },
        -- 3. Medical Supplies (always available)
        {   title = locale('cl_medical_supplies'),
            icon = 'fa-solid fa-pills',
            description = locale('cl_desc_purchase_supplies'),
            event = 'QC-AdvancedMedic:client:OpenMedicSupplies',
            arrow = true
        },
        {
            title = locale('cl_menu_start_medical_mission'),
            icon = 'fa-solid fa-briefcase-medical',
            event = 'QC-AdvancedMedic:client:startMission',
            arrow = true
        },
    }
    
    -- 4. Pharmaceutical Supplies (Pharmacist and Boss only)
    if isPharmacist or isBoss then
        table.insert(menuOptions, {
            title = locale('cl_pharmaceutical_supplies') or 'Pharmaceutical Supplies',
            icon = 'fa-solid fa-flask',
            description = locale('cl_desc_experimental_medicine'),
            event = 'QC-AdvancedMedic:client:OpenPharmaceuticalShop',
            arrow = true
        })
    end
    
    -- 5. Manage Employees (Boss only - always last)
    if isBoss then
        table.insert(menuOptions, {
            title = locale('cl_employees'),
            icon = 'fa-solid fa-list',
            description = locale('cl_employees_b'),
            event = 'rsg-bossmenu:client:mainmenu',
            arrow = true
        })
    end

    lib.registerContext({
        id = "medic_mainmenu",
        title = name,
        options = menuOptions
    })
    lib.showContext("medic_mainmenu")
end)

-- medicmenu handler (for back buttons)
AddEventHandler('QC-AdvancedMedic:client:medicmenu', function(data)
    if data and data.location then
        TriggerEvent('QC-AdvancedMedic:client:mainmenu', data.location, data.location)
    end
end)

---------------------------------------------------------------------
-- duty management system
---------------------------------------------------------------------
local dutyStartTime = nil
local sessionTime = 0

-- Function to format time (seconds to HH:MM:SS)
local function FormatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Function to get session duty time
local function GetSessionDutyTime()
    if dutyStartTime then
        return GetGameTimer() - dutyStartTime
    end
    return sessionTime
end

-- Enhanced duty menu
AddEventHandler('QC-AdvancedMedic:client:OpenDutyMenu', function()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local onDuty = PlayerData.job.onduty
    local sessionTimeMs = GetSessionDutyTime()
    local sessionTimeFormatted = FormatTime(math.floor(sessionTimeMs / 1000))
    
    local dutyStatusText = onDuty and "✅ ON DUTY" or "❌ OFF DUTY"
    local dutyStatusColor = onDuty and "green" or "red"
    
    lib.registerContext({
        id = "medic_duty_menu",
        title = locale('cl_menu_duty_management'),
        options = {
            {   title = locale('cl_menu_current_status') .. dutyStatusText,
                icon = onDuty and 'fa-solid fa-user-check' or 'fa-solid fa-user-times',
                description = locale('cl_desc_current_duty_status'),
                readOnly = true
            },
            {   title = locale('cl_menu_session_time') .. sessionTimeFormatted,
                icon = 'fa-solid fa-clock',
                description = locale('cl_desc_duty_time'),
                readOnly = true
            },
            {   title = onDuty and "Go Off Duty" or "Go On Duty",
                icon = onDuty and 'fa-solid fa-sign-out-alt' or 'fa-solid fa-sign-in-alt',
                description = onDuty and "Clock out and go off duty" or "Clock in and go on duty",
                event = 'QC-AdvancedMedic:client:ToggleDutyStatus',
                arrow = true
            },
            {   title = locale('cl_menu_back_main'),
                icon = 'fa-solid fa-arrow-left',
                description = locale('cl_desc_return_menu'),
                event = 'QC-AdvancedMedic:client:medicmenu',
                args = { location = mediclocation }
            }
        }
    })
    lib.showContext("medic_duty_menu")
end)

-- Toggle duty with time tracking
AddEventHandler('QC-AdvancedMedic:client:ToggleDutyStatus', function()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local wasOnDuty = PlayerData.job.onduty
    
    if wasOnDuty then
        -- Going off duty - calculate session time
        if dutyStartTime then
            sessionTime = sessionTime + (GetGameTimer() - dutyStartTime)
            dutyStartTime = nil
        end
        
        -- Send session time to server for payment calculation
        local totalSessionTimeSeconds = math.floor(sessionTime / 1000)
        TriggerServerEvent('QC-AdvancedMedic:server:ProcessDutyPay', totalSessionTimeSeconds)
        
        lib.notify({
            title = locale('cl_menu_clocked_out'),
            description = string.format(locale('cl_desc_fmt_session_time'), FormatTime(totalSessionTimeSeconds)),
            type = 'success',
            duration = 5000
        })
        
        -- Reset for next session
        sessionTime = 0
    else
        -- Going on duty - start timer and automatic pay system
        dutyStartTime = GetGameTimer()
        TriggerServerEvent('QC-AdvancedMedic:server:StartDutyPayTimer')
        lib.notify({
            title = locale('cl_menu_clocked_in'),
            description = locale('cl_desc_now_on_duty'),
            type = 'success',
            duration = 3000
        })
    end
    
    -- Toggle duty status
    TriggerServerEvent("RSGCore:ToggleDuty")
    
    -- Refresh the duty menu after a short delay
    Wait(1000)
    TriggerEvent('QC-AdvancedMedic:client:OpenDutyMenu')
end)

-- Update timer display every minute when duty menu is open
CreateThread(function()
    while true do
        Wait(60000) -- Update every minute
        -- This will automatically refresh if the menu is open due to the time calculation
    end
end)

---------------------------------------------------------------------
-- medic supplies
---------------------------------------------------------------------
-- Helper function to check if current job is a medic job
local function IsPlayerMedic()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local job = PlayerData.job.name
    
    for _, location in pairs(Config.MedicJobLocations) do
        if location.job == job then
            return true
        end
    end
    return false
end

AddEventHandler('QC-AdvancedMedic:client:OpenMedicSupplies', function()
    if not CanAccessLocation(mediclocation) then 
        lib.notify({ title = locale('cl_access_denied'), description = locale('cl_no_access_facility'), type = 'error', duration = 5000 })
        return 
    end
    TriggerServerEvent('rsg-shops:server:openstore', 'medic', 'medic', locale('cl_medical_supplies'))
end)

---------------------------------------------------------------------
-- pharmaceutical supplies (1890s medical shop)
---------------------------------------------------------------------
AddEventHandler('QC-AdvancedMedic:client:OpenPharmaceuticalShop', function()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local job = PlayerData.job.name
    local grade = PlayerData.job.grade.level
    local isBoss = PlayerData.job.grade.isboss
    
    if not CanAccessLocation(mediclocation) then 
        lib.notify({ title = locale('cl_access_denied'), description = locale('cl_no_access_facility'), type = 'error', duration = 5000 })
        return 
    end
    
    if grade < 2 and not isBoss then
        lib.notify({ title = locale('cl_access_denied'), description = locale('cl_pharmacist_only'), type = 'error', duration = 5000 })
        return
    end
    
    -- Create pharmaceutical shop menu
    local pharmaceuticalOptions = {}
    
    -- Add header
    table.insert(pharmaceuticalOptions, {
        title = locale('cl_menu_pharmaceutical_dispensary'),
        description = locale('cl_desc_medical_compounds'),
        readOnly = true,
        icon = 'fa-solid fa-mortar-pestle'
    })
    
    -- Medicines Section
    table.insert(pharmaceuticalOptions, {
        title = locale('cl_menu_medicines_header'),
        readOnly = true,
        icon = 'fa-solid fa-pills'
    })
    
    for medicineType, config in pairs(Config.MedicineTypes) do
        table.insert(pharmaceuticalOptions, {
            title = config.label .. " - $" .. (config.price or 25),
            description = config.description,
            icon = 'fa-solid fa-pill',
            event = 'QC-AdvancedMedic:client:PurchasePharmaceutical',
            args = { type = 'medicine', item = config.itemName, price = config.price or 25, label = config.label }
        })
    end
    
    -- Injections Section
    table.insert(pharmaceuticalOptions, {
        title = locale('cl_menu_injections_header'),
        readOnly = true,
        icon = 'fa-solid fa-syringe'
    })
    
    for injectionType, config in pairs(Config.InjectionTypes) do
        table.insert(pharmaceuticalOptions, {
            title = config.label .. " - $" .. (config.price or 50),
            description = config.description,
            icon = 'fa-solid fa-syringe',
            event = 'QC-AdvancedMedic:client:PurchasePharmaceutical',
            args = { type = 'injection', item = config.itemName, price = config.price or 50, label = config.label }
        })
    end
    
    -- Back option
    table.insert(pharmaceuticalOptions, {
        title = locale('cl_menu_back_main'),
        icon = 'fa-solid fa-arrow-left',
        event = 'QC-AdvancedMedic:client:medicmenu',
        args = { location = mediclocation }
    })
    
    lib.registerContext({
        id = "pharmaceutical_shop",
        title = locale('cl_menu_pharma_title'),
        options = pharmaceuticalOptions
    })
    lib.showContext("pharmaceutical_shop")
end)

-- Purchase pharmaceutical item
AddEventHandler('QC-AdvancedMedic:client:PurchasePharmaceutical', function(data)
    local input = lib.inputDialog('Purchase ' .. data.label, {
        {type = 'number', label = 'Quantity', description = locale('cl_desc_quantity_purchase'), default = 1, min = 1, max = 10}
    })
    
    if input and input[1] then
        local quantity = tonumber(input[1])
        local totalCost = (data.price or 25) * quantity
        
        TriggerServerEvent('QC-AdvancedMedic:server:PurchasePharmaceutical', {
            item = data.item,
            quantity = quantity,
            price = data.price or 25,
            totalCost = totalCost,
            label = data.label,
            type = data.type
        })
    end
end)

---------------------------------------------------------------------
-- death cam
---------------------------------------------------------------------
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
            local waitTime = Config.DeadMoveCam and 16 or 1000 -- 16ms for free-look, 1000ms for overhead
            Wait(waitTime)

            if deathactive and not deadcam then
                StartDeathCam()
            elseif deadcam and Dead and Config.DeadMoveCam then
                -- Process optimized free-look camera
                ProcessCamControls()
            end

            if deathSecondsRemaining <= 0 and not deathactive then return end
        end
    end)
end)

---------------------------------------------------------------------
-- get medics on-duty
---------------------------------------------------------------------
AddEventHandler('QC-AdvancedMedic:client:GetMedicsOnDuty', function()
    RSGCore.Functions.TriggerCallback('QC-AdvancedMedic:server:getmedics', function(mediccount)
        medicsonduty = mediccount
    end)
end)

-- Player Revive After Pressing [E]
AddEventHandler('QC-AdvancedMedic:client:revive', function()
    SetClosestRespawn()

    -- Hide death screen NUI and disable focus
    SendNUIMessage({
        type = 'hide-death-screen'
    })
    SetNuiFocus(false, false)
    nuiFocusEnabled = false

    if deathactive then
        DoScreenFadeOut(500)

        Wait(1000)

        local respawnPos = Config.RespawnLocations[closestRespawn].coords
        -- Fixed: NetworkResurrectLocalPlayer expects x, y, z, heading parameters
        NetworkResurrectLocalPlayer(respawnPos.x, respawnPos.y, respawnPos.z, Config.RespawnLocations[closestRespawn].coords.w or 0.0, true, false)
        SetEntityInvincible(cache.ped, false)
        ClearPedBloodDamage(cache.ped)
        PlayPain(cache.ped, 4, 1, true, true)
        SetAttributeCoreValue(cache.ped, 0, 100)
        SetAttributeCoreValue(cache.ped, 1, 100)
        TriggerServerEvent("RSGCore:Server:SetMetaData", "hunger", 100)
        TriggerServerEvent("RSGCore:Server:SetMetaData", "thirst", 100)
        TriggerServerEvent("RSGCore:Server:SetMetaData", "cleanliness", 100)
        TriggerServerEvent('QC-AdvancedMedic:server:SetHealth', Config.MaxHealth)

        -- Reset Outlaw Status on respawn
        if Config.ResetOutlawStatus then
            TriggerServerEvent('rsg-prison:server:resetoutlawstatus')
        end

        -- Reset Death Timer
        deathactive = false
        deathTimerStarted = false
        medicCalled = false
        deathSecondsRemaining = 0

        AnimpostfxPlay("Title_Gen_FewHoursLater", 0, false)
        Wait(3000)
        DoScreenFadeIn(2000)
        AnimpostfxPlay("PlayerWakeUpInterrogation", 0, false)
        Wait(19000)
        SetNuiFocus(false, false)

        TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", false)
    end
end)

---------------------------------------------------------------------
-- admin revive
---------------------------------------------------------------------
-- Admin Revive
RegisterNetEvent('QC-AdvancedMedic:client:adminRevive', function()
    -- Hide death screen NUI and disable focus
    SendNUIMessage({
        type = 'hide-death-screen'
    })
    SetNuiFocus(false, false)
    nuiFocusEnabled = false

    local player = PlayerPedId()
    local pos = GetEntityCoords(cache.ped, true)

    DoScreenFadeOut(500)

    Wait(1000)

    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(player), true, false)
    SetEntityInvincible(cache.ped, false)
    ClearPedBloodDamage(cache.ped)
    PlayPain(cache.ped, 4, 1, true, true)
    SetAttributeCoreValue(cache.ped, 0, 100) -- SetAttributeCoreValue
    SetAttributeCoreValue(cache.ped, 1, 100) -- SetAttributeCoreValue
    TriggerServerEvent("RSGCore:Server:SetMetaData", "hunger", 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "thirst", 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "cleanliness", 100)
    -- NOTE: Wounds persist through self-revive - use /clearwounds command to clear them

    -- Reset Outlaw Status on respawn
    if Config.ResetOutlawStatus then
        TriggerServerEvent('rsg-prison:server:resetoutlawstatus')
    end

    -- Reset Death Timer
    deathactive = false
    deathTimerStarted = false
    medicCalled = false
    deathSecondsRemaining = 0

    Wait(1500)

    DoScreenFadeIn(1800)

    TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", false)
end)

---------------------------------------------------------------------
-- player revive
---------------------------------------------------------------------
RegisterNetEvent('QC-AdvancedMedic:client:playerRevive', function()
    -- Hide death screen NUI and disable focus
    SendNUIMessage({
        type = 'hide-death-screen'
    })
    SetNuiFocus(false, false)
    nuiFocusEnabled = false

    local pos = GetEntityCoords(cache.ped, true)

    DoScreenFadeOut(500)

    Wait(1000)

    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(cache.ped), true, false)
    SetEntityInvincible(cache.ped, false)
    ClearPedBloodDamage(cache.ped)
    PlayPain(cache.ped, 4, 1, true, true)
    SetAttributeCoreValue(cache.ped, 0, 100) -- SetAttributeCoreValue
    SetAttributeCoreValue(cache.ped, 1, 100) -- SetAttributeCoreValue
    TriggerServerEvent("RSGCore:Server:SetMetaData", "hunger", 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "thirst", 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "cleanliness", 100)
    TriggerServerEvent('QC-AdvancedMedic:server:SetHealth', Config.MaxHealth)
    -- NOTE: Wounds persist through admin/player revive - use /clearwounds command to clear them
    -- Reset Outlaw Status on respawn
    if Config.ResetOutlawStatus then
        TriggerServerEvent('rsg-prison:server:resetoutlawstatus')
    end

    -- Reset Death Timer
    deathactive = false
    deathTimerStarted = false
    medicCalled = false
    deathSecondsRemaining = 0

    Wait(1500)

    DoScreenFadeIn(1800)

    TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", false)
end)

---------------------------------------------------------------------
-- admin Heal
---------------------------------------------------------------------
RegisterNetEvent('QC-AdvancedMedic:client:adminHeal', function()
    local player = PlayerPedId()
    local pos = GetEntityCoords(cache.ped, true)
    Wait(1000)
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(player), true, false)
    SetEntityInvincible(cache.ped, false)
    ClearPedBloodDamage(cache.ped)
    SetAttributeCoreValue(cache.ped, 0, 100) -- SetAttributeCoreValue
    SetAttributeCoreValue(cache.ped, 1, 100) -- SetAttributeCoreValue
    TriggerServerEvent("RSGCore:Server:SetMetaData", "hunger", 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "thirst", 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "cleanliness", 100)
    TriggerServerEvent('QC-AdvancedMedic:server:SetHealth', Config.MaxHealth)
    TriggerEvent('QC-AdvancedMedic:ResetLimbs')
    lib.notify({title = locale('cl_beenhealed'), duration = 5000, type = 'inform'})
end)
---------------------------------------------------------------------
-- Player Heal
---------------------------------------------------------------------
RegisterNetEvent('QC-AdvancedMedic:client:playerHeal', function()
    -- Hide death screen NUI and disable focus
    SendNUIMessage({
        type = 'hide-death-screen'
    })
    SetNuiFocus(false, false)
    nuiFocusEnabled = false
    
    local pos = GetEntityCoords(cache.ped, true)
    Wait(1000)
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(cache.ped), true, false)
    SetEntityInvincible(cache.ped, false)
    ClearPedBloodDamage(cache.ped)
    SetAttributeCoreValue(cache.ped, 0, 100) -- SetAttributeCoreValue
    SetAttributeCoreValue(cache.ped, 1, 100) -- SetAttributeCoreValue
    TriggerServerEvent("RSGCore:Server:SetMetaData", "hunger", 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "thirst", 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "cleanliness", 100)
    TriggerServerEvent('QC-AdvancedMedic:server:SetHealth', Config.MaxHealth)
    TriggerEvent('QC-AdvancedMedic:ResetLimbs')
    lib.notify({title = locale('cl_beenhealed'), duration = 5000, type = 'inform'})
end)

---------------------------------------------------------------------
-- medic storage
---------------------------------------------------------------------
AddEventHandler('QC-AdvancedMedic:client:storage', function()
    local job = RSGCore.Functions.GetPlayerData().job.name
    local stashloc = mediclocation

    if not IsMedicJob(job) then return end
    TriggerServerEvent('QC-AdvancedMedic:server:openstash', stashloc)
end)

---------------------------------------------------------------------
-- kill player
---------------------------------------------------------------------
RegisterNetEvent('QC-AdvancedMedic:client:KillPlayer')
AddEventHandler('QC-AdvancedMedic:client:KillPlayer', function()
    SetEntityHealth(cache.ped, 0)
end)

---------------------------------------------------------------------
-- Handle vitals check response from server
---------------------------------------------------------------------
RegisterNetEvent('QC-AdvancedMedic:client:VitalsResponse')
AddEventHandler('QC-AdvancedMedic:client:VitalsResponse', function(vitalsData)
    -- Send vitals data to NUI for realistic pulse calculation
    SendNUIMessage({
        type = 'vitals-response',
        health = vitalsData.health,
        isDead = vitalsData.isDead,
        isUnconscious = vitalsData.isUnconscious,
        targetName = vitalsData.targetName
    })
end)

---------------------------------------------------------------------
-- Send vitals data to requesting medic (client-side health detection)
---------------------------------------------------------------------
RegisterNetEvent('QC-AdvancedMedic:client:SendVitalsToMedic')
AddEventHandler('QC-AdvancedMedic:client:SendVitalsToMedic', function(medicSource)
    -- Get accurate health data from client-side
    local ped = PlayerPedId()
    local health = GetEntityHealth(ped)
    local maxHealth = Config.MaxHealth or 600
    local healthPercent = math.floor((health / maxHealth) * 100)
    local isDead = health <= 0 or Dead -- Use local dead state
    local isUnconscious = false -- Could add unconscious detection here
    
    print(string.format('^2[QC-AdvancedMedic] Sending CLIENT vitals to medic %d: Health=%d, Dead=%s^7', 
        medicSource, healthPercent, tostring(isDead)))
    
    local vitalsData = {
        health = healthPercent,
        isDead = isDead,
        isUnconscious = isUnconscious
    }
    
    -- Send vitals data back to server for relay to medic
    TriggerServerEvent('QC-AdvancedMedic:server:ReceiveVitalsData', medicSource, vitalsData)
end)

---------------------------------------------------------------------
-- Store config data received on player load (performance optimization)
---------------------------------------------------------------------
local ClientConfigData = {}

RegisterNetEvent('QC-AdvancedMedic:client:ReceiveConfigs')
AddEventHandler('QC-AdvancedMedic:client:ReceiveConfigs', function(configData)
    ClientConfigData = configData
    print('^2[QC-AdvancedMedic] Config data cached on client^7')
end)

---------------------------------------------------------------------
-- Handle vitals check request from NUI
---------------------------------------------------------------------
RegisterNUICallback('medical-request', function(data, cb)
    if data.action == 'check-vitals' then
        -- Get health data client-side for the target player
        local targetId = data.data.playerSource or data.data.playerId
        
        if targetId == GetPlayerServerId(PlayerId()) then
            -- Checking own vitals - get directly from client
            local ped = PlayerPedId()
            local health = GetEntityHealth(ped)
            local maxHealth = Config.MaxHealth or 600
            local healthPercent = math.floor((health / maxHealth) * 100)
            local isDead = health <= 0 or Dead -- Use local dead state
            
            print(string.format('^2[QC-AdvancedMedic] CLIENT-SIDE VITALS: Health=%d, MaxHealth=%d, Percent=%d%%, Dead=%s^7', 
                health, maxHealth, healthPercent, tostring(isDead)))
            
            -- Send vitals data directly to NUI
            SendNUIMessage({
                type = 'vitals-response',
                health = healthPercent,
                isDead = isDead,
                isUnconscious = false -- Could check for unconscious state here
            })
        else
            -- Checking another player - request from server but send client health too
            TriggerServerEvent('QC-AdvancedMedic:server:CheckVitals', targetId)
        end
        cb('ok')
    end
end)

---------------------------------------------------------------------
-- check for self treatment (missing event handler for server integration)
---------------------------------------------------------------------
RegisterNetEvent('QC-AdvancedMedic:client:CheckForSelfTreatment')
AddEventHandler('QC-AdvancedMedic:client:CheckForSelfTreatment', function(treatmentType, itemType)
    if treatmentType == 'bandage' then
        TriggerEvent('QC-AdvancedMedic:client:usebandage', itemType)
    elseif treatmentType == 'tourniquet' then
        TriggerEvent('QC-AdvancedMedic:client:usetourniquet', itemType)
    end
end)


---------------------------------------------------------------------
-- show inspection panel for medic examination
---------------------------------------------------------------------
RegisterNetEvent('QC-AdvancedMedic:client:ShowInspectionPanel')
AddEventHandler('QC-AdvancedMedic:client:ShowInspectionPanel', function(inspectionData)
    if not inspectionData then
        lib.notify({
            title = locale('cl_menu_inspection_error'),
            description = locale('cl_desc_no_medical_data'),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Enable NUI focus for interaction
    SetNuiFocus(true, true)
    
    -- Show cursor
    SetCursorLocation(0.5, 0.5)
    
    
    -- Merge inspection data with cached config data for performance
    local mergedData = {}
    for k, v in pairs(inspectionData) do
        mergedData[k] = v
    end
    for k, v in pairs(ClientConfigData) do
        mergedData[k] = v
    end
    
    -- Send data to React frontend to show inspection panel
    SendNUIMessage({
        type = 'show-inspection-panel',
        data = mergedData
    })
    
    -- Debug print to check if message is being sent
    print("^2[NUI DEBUG] Sent show-inspection-panel message with player: " .. (inspectionData.playerName or "Unknown"))
    print("^2[NUI DEBUG] Using cached config data for performance optimization")
    
    if Config.WoundSystem.debugging.enabled then
        print(string.format("[INSPECTION] Opening inspection panel for: %s", inspectionData.playerName or "Unknown"))
    end
end)

---------------------------------------------------------------------
-- hide inspection panel
---------------------------------------------------------------------
RegisterNetEvent('QC-AdvancedMedic:client:HideInspectionPanel')
AddEventHandler('QC-AdvancedMedic:client:HideInspectionPanel', function()
    -- Disable NUI focus
    SetNuiFocus(false, false)
    
    -- Hide all panels
    SendNUIMessage({
        type = 'hide-all'
    })
end)

---------------------------------------------------------------------
-- NUI callback handlers for inspection panel actions
---------------------------------------------------------------------
RegisterNUICallback('closeInspectionPanel', function(data, cb)
    TriggerEvent('QC-AdvancedMedic:client:HideInspectionPanel')
    cb({status = 'ok'})
end)

RegisterNUICallback('applyTreatment', function(data, cb)
    local bodyPart = data.bodyPart
    local treatmentType = data.treatmentType
    local targetPlayerId = data.targetPlayerId
    
    if not bodyPart or not treatmentType or not targetPlayerId then
        cb({status = 'error', message = 'Invalid treatment data'})
        return
    end
    
    -- Hide inspection panel first
    TriggerEvent('QC-AdvancedMedic:client:HideInspectionPanel')
    
    -- Trigger appropriate server event based on treatment type
    if treatmentType == 'bandage' then
        TriggerServerEvent('QC-AdvancedMedic:server:MedicApplyBandage', targetPlayerId, bodyPart, data.itemType or 'cotton_band')
    elseif treatmentType == 'tourniquet' then
        TriggerServerEvent('QC-AdvancedMedic:server:MedicApplyTourniquet', targetPlayerId, bodyPart, data.itemType or 'tourniquet_rope')
    elseif treatmentType == 'medicine' then
        TriggerServerEvent('QC-AdvancedMedic:server:MedicApplyMedicine', targetPlayerId, bodyPart, data.itemType or 'laudanum')
    end
    
    cb({status = 'ok'})
end)

---------------------------------------------------------------------
-- NUI callback handlers for death screen
---------------------------------------------------------------------
RegisterNUICallback('death-respawn', function(data, cb)
    -- Hide death screen and disable NUI focus first
    SendNUIMessage({ type = 'hide-death-screen' })
    SetNuiFocus(false, false)
    nuiFocusEnabled = false
    
    if deathSecondsRemaining <= 0 then
        -- Trigger self-respawn (no medic helped)
        TriggerEvent('QC-AdvancedMedic:client:revive')
        TriggerServerEvent('QC-AdvancedMedic:server:deathactions')
    end
    cb({status = 'ok'})
end)

RegisterNUICallback('death-call-medic', function(data, cb)
    TriggerEvent('QC-AdvancedMedic:client:MedicCall')
    cb({status = 'ok'})
end)

-- Medic call event handler
RegisterNetEvent('QC-AdvancedMedic:client:MedicCall', function()
    if not medicCalled then
        medicCalled = true
        
        if medicsonduty == 0 then
            lib.notify({
                title = locale('cl_menu_no_medics_available'),
                description = locale('cl_desc_no_medics_on_duty'),
                type = 'error',
                icon = 'fa-solid fa-kit-medical',
                iconAnimation = 'shake',
                duration = 5000
            })
            MedicCalled() -- Reset the cooldown
            return
        end

        -- Send emergency call to medics
        local pos = GetEntityCoords(cache.ped)
        TriggerServerEvent('QC-AdvancedMedic:server:EmergencyCall', pos)
        
        lib.notify({
            title = locale('cl_menu_emergency_call_sent'),
            description = locale('cl_desc_assistance_requested'),
            type = 'success',
            icon = 'fa-solid fa-kit-medical',
            iconAnimation = 'shake',
            duration = 7000
        })
        
        MedicCalled() -- Start cooldown
    else
        lib.notify({
            title = locale('cl_menu_please_wait'),
            description = locale('cl_desc_already_called_assistance'),
            type = 'inform',
            duration = 3000
        })
    end
end)

RegisterNUICallback('hide-death-screen', function(data, cb)
    SendNUIMessage({ type = 'hide-death-screen' })
    cb({status = 'ok'})
end)

-- Handle tool usage result from server (NUI handles notifications)
RegisterNetEvent('QC-AdvancedMedic:client:ToolUsageResult')
AddEventHandler('QC-AdvancedMedic:client:ToolUsageResult', function(result)
    if not result then return end

    if Config.Debug then
        print(string.format("^3[CLIENT ToolUsageResult] success=%s, message=%s, refreshInventory=%s^7",
            tostring(result.success), tostring(result.message), tostring(result.refreshInventory)))
    end

    -- Send result to NUI for notification display
    SendNUIMessage({
        type = 'tool-usage-result',
        data = {
            success = result.success,
            message = result.message
        }
    })

    -- If inventory needs refresh (item ran out or was consumed)
    if result.refreshInventory then
        -- Request updated inspection data from server
        -- This silently updates inventory in background without closing NUI
        Wait(500)  -- Small delay to let server process
        TriggerServerEvent('QC-AdvancedMedic:server:RefreshMedicInventory')
    end
end)

-- Server sends updated inventory after tool usage
RegisterNetEvent('QC-AdvancedMedic:client:UpdateMedicInventory')
AddEventHandler('QC-AdvancedMedic:client:UpdateMedicInventory', function(medicInventory)
    -- Send updated inventory to NUI without closing panel
    SendNUIMessage({
        type = 'update-medic-inventory',
        data = medicInventory
    })

    if Config.Debug then
        print("^2[DOCTOR BAG] Updated medic inventory in NUI^7")
    end
end)

-- Emergency alert for medics
RegisterNetEvent('QC-AdvancedMedic:client:EmergencyAlert', function(data)
    lib.notify({
        title = locale('cl_menu_emergency_medical_call'),
        description = string.format(locale('cl_desc_fmt_needs_medical_assistance'), data.caller),
        type = 'error',
        icon = 'fa-solid fa-ambulance',
        iconAnimation = 'bounce',
        duration = 10000
    })
    
    -- Set waypoint to emergency location
    SetNewWaypoint(data.location.x, data.location.y)
    
    -- Play emergency sound
    PlaySoundFrontend('Emergency_SOS', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true, 1)
end)

-- Disable NUI Focus Callback (called from NUI on right-click when focused)
RegisterNUICallback('disable-nui-focus', function(data, cb)
    SetNuiFocus(false, false)
    nuiFocusEnabled = false
    
    lib.notify({
        title = locale('cl_menu_nui_focus'),
        description = locale('cl_desc_mouse_disabled'),
        type = 'inform',
        duration = 3000
    })
    
    cb({status = 'ok'})
end)

-- Handle doctor bag tool usage from NUI (including medicines clicked from doctor bag)
RegisterNUICallback('medical-action', function(data, cb)
    local action = data.action
    local target = data.target
    local targetPlayerId = data.playerId

    if not action or not target then
        cb({status = 'error', message = 'Invalid medical action data'})
        return
    end

    if Config.Debug then
        print(string.format("^3[NUI MEDICAL-ACTION] Action: %s, Target: %s, PlayerId: %s^7", action, target, tostring(targetPlayerId)))
    end

    -- Handle 'use-tool' actions from doctor bag
    if action == 'use-tool' then
        -- Map NUI tool actions to server actions
        local toolActionMap = {
            -- Diagnostic tools
            ['smelling-salts'] = 'revive_unconscious',
            ['stethoscope'] = 'check_heart_lungs',
            ['thermometer'] = 'check_temperature',
            ['field-kit'] = 'emergency_surgery',
            -- Medicines (from doctor bag - need inventory check + removal)
            ['laudanum'] = 'medicine_laudanum',
            ['whiskey'] = 'medicine_whiskey'
        }

        local toolAction = toolActionMap[target]

        if not toolAction then
            cb({status = 'error', message = 'Unknown tool: ' .. tostring(target)})
            return
        end

        if Config.Debug then
            print(string.format("^3[CLIENT] Triggering server event UseDoctorBagTool with toolAction=%s, targetPlayerId=%s^7", tostring(toolAction), tostring(targetPlayerId)))
        end

        -- Send to server to use tool (server validates inventory + removes item)
        TriggerServerEvent('QC-AdvancedMedic:server:UseDoctorBagTool', toolAction, targetPlayerId)

        if Config.Debug then
            print("^3[CLIENT] Server event triggered, returning pending status^7")
        end

        cb({status = 'pending', message = 'Processing...'})
    else
        cb({status = 'error', message = 'Unknown medical action: ' .. tostring(action)})
    end
end)

-- Handle medical treatment messages from NUI (via window.postMessage)
RegisterNUICallback('medical-treatment', function(data, cb)
    print(json.encode(data))
    local action = data.action
    local treatmentData = data.data
    local targetPlayerId = treatmentData.playerId

    if not action or not treatmentData then
        cb({status = 'error', message = 'Invalid treatment data'})
        return
    end
    
    if Config.Debug then
        print(string.format("^3[NUI MEDICAL-TREATMENT] Action: %s, Data: %s^7", action, json.encode(treatmentData)))
    end
    
    -- Route to appropriate treatment handler
    if action == 'administer-medicine' then
        -- Use the existing administer-medicine callback logic
        local medicineType = treatmentData.itemType
        
        if not medicineType then
            cb({status = 'error', message = 'Missing medicine type'})
            return
        end
        
        -- Check if player has the medicine item
        local medicineConfig = Config.MedicineTypes[medicineType]
        if not medicineConfig then
            cb({status = 'error', message = 'Unknown medicine type: ' .. tostring(medicineType)})
            return
        end
        
        local itemName = medicineConfig.itemName
        local hasItem = RSGCore.Functions.HasItem(itemName, 1)
        
        if not hasItem then
            cb({
                status = 'error', 
                message = 'You do not have ' .. (medicineConfig.label or itemName) .. ' in your inventory'
            })
            return
        end
        
        -- Check if this is a mission NPC (source = -1) or real player
        if targetPlayerId == -1 or targetPlayerId == "-1" then
            -- Handle mission NPC medicine application
            TriggerEvent('QC-AdvancedMedic:client:ApplyMissionMedicine', medicineType)
            
            -- Wait a moment for treatment to be applied, then send updated wound data
            Citizen.SetTimeout(100, function()
                TriggerEvent('QC-AdvancedMedic:client:RefreshMissionNUI')
            end)
            
            cb({status = 'success', message = 'Medicine administered to mission patient'})
            
            if Config.Debug then
                print("^3[MEDICAL-TREATMENT] Administered " .. medicineType .. " to mission NPC^7")
            end
        else
            -- Handle real player medicine application
            print(string.format("^3[MEDICAL-TREATMENT] Administering %s to player %s^7", medicineType, tostring(targetPlayerId)))
            TriggerServerEvent('QC-AdvancedMedic:server:MedicApplyMedicine', targetPlayerId, medicineType)
            cb({status = 'success', message = 'Medicine administered successfully'})
            
            if Config.Debug then
                print("^3[MEDICAL-TREATMENT] Administered " .. medicineType .. " to player " .. targetPlayerId .. "^7")
            end
        end
        
    elseif action == 'apply-bandage' then
        local bodyPart = treatmentData.bodyPart
        local bandageType = treatmentData.itemType
        
        if targetPlayerId == -1 or targetPlayerId == "-1" then
            -- Handle mission NPC bandage application
            TriggerEvent('QC-AdvancedMedic:client:ApplyMissionBandage', bodyPart, bandageType)
            
            -- Wait a moment for treatment to be applied, then send updated wound data
            Citizen.SetTimeout(100, function()
                TriggerEvent('QC-AdvancedMedic:client:RefreshMissionNUI')
            end)
            
            cb({status = 'success', message = 'Bandage applied to mission patient'})
        else
            print(string.format("^3[MEDICAL-TREATMENT] Applying %s bandage to player %s on body part %s^7", bandageType, tostring(targetPlayerId), bodyPart))
            -- Handle real player bandage application
            TriggerServerEvent('QC-AdvancedMedic:server:MedicApplyBandage', targetPlayerId, bodyPart, bandageType)
            cb({status = 'success', message = 'Bandage applied successfully'})
        end
        
    elseif action == 'apply-tourniquet' then
        local bodyPart = treatmentData.bodyPart
        local tourniquetType = treatmentData.itemType
        
        if targetPlayerId == -1 or targetPlayerId == "-1" then
            -- Handle mission NPC tourniquet application
            TriggerEvent('QC-AdvancedMedic:client:ApplyMissionTourniquet', bodyPart, tourniquetType)
            cb({status = 'success', message = 'Tourniquet applied to mission patient'})
        else
            -- Handle real player tourniquet application
            TriggerServerEvent('QC-AdvancedMedic:server:MedicApplyTourniquet', targetPlayerId, bodyPart, tourniquetType)
            cb({status = 'success', message = 'Tourniquet applied successfully'})
        end
        
    else
        cb({status = 'error', message = 'Unknown treatment action: ' .. tostring(action)})
    end
end)


---------------------------------------------------------------------
-- use bandage (reworked for new 4-type system)
---------------------------------------------------------------------
RegisterNetEvent('QC-AdvancedMedic:client:usebandage', function(bandageType)
    if isBusy then return end
    
    -- Default to cotton if no type specified (backwards compatibility)
    bandageType = bandageType or 'cotton'
    
    -- Get bandage config and item name from config
    local bandageConfig = Config.BandageTypes[bandageType]
    if not bandageConfig then
        lib.notify({
            title = locale('cl_menu_configuration_error'),
            description = string.format(locale('cl_desc_fmt_unknown_bandage_type'), bandageType),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Use itemName from config, fallback to bandageType key if not specified
    local itemName = bandageConfig.itemName or bandageType
    
    local hasItem = RSGCore.Functions.HasItem(itemName, 1)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    
    if not PlayerData.metadata['isdead'] and not PlayerData.metadata['ishandcuffed'] then
        if hasItem then
            -- Check if player has any wounds to treat
            local wounds = PlayerWounds or {}
            if not next(wounds) then
                lib.notify({
                    title = locale('cl_error'),
                    description = locale('cl_desc_no_wounds_bandaging'),
                    type = 'error',
                    duration = 5000
                })
                return
            end
            
            -- Check if specific body part was requested via /usebandage command
            local targetBodyPart = nil
            
            if targetBodyPartOverride then
                -- Command specified exact body part - validate it has a wound
                if wounds[targetBodyPartOverride] then
                    targetBodyPart = targetBodyPartOverride
                else
                    lib.notify({
                        title = locale('cl_menu_treatment_error'),
                        description = string.format(locale('cl_desc_fmt_no_wound_detected'),
                            Config.BodyParts[targetBodyPartOverride] and Config.BodyParts[targetBodyPartOverride].label or targetBodyPartOverride),
                        type = 'error',
                        duration = 5000
                    })
                    targetBodyPartOverride = nil  -- Reset override
                    return
                end
                targetBodyPartOverride = nil  -- Reset override after use
            else
                -- Original behavior: find the most severe wound (prioritize bleeding > pain)
                local highestSeverity = 0
                
                for bodyPart, wound in pairs(wounds) do
                    -- Prioritize bleeding wounds for bandage treatment
                    local severity = (wound.bleedingLevel * 2) + wound.painLevel
                    if severity > highestSeverity then
                        highestSeverity = severity
                        targetBodyPart = bodyPart
                    end
                end
                
                if not targetBodyPart then
                    lib.notify({
                        title = locale('cl_error'),
                        description = locale('cl_desc_no_suitable_wound'),
                        type = 'error',
                        duration = 5000
                    })
                    return
                end
            end
            
            -- Check if this body part already has a bandage
            local activeTreatments = ActiveTreatments or {}
            if activeTreatments[targetBodyPart] and activeTreatments[targetBodyPart].treatmentType == "bandage" then
                lib.notify({
                    title = locale('cl_menu_treatment_error'),
                    description = string.format(locale('cl_desc_fmt_bandage_already_applied'),
                        Config.BodyParts[targetBodyPart] and Config.BodyParts[targetBodyPart].label or targetBodyPart),
                    type = 'error',
                    duration = 5000
                })
                return
            end
            
            isBusy = true
            LocalPlayer.state:set('inv_busy', true, true)
            SetCurrentPedWeapon(cache.ped, GetHashKey('weapon_unarmed'))

            lib.progressBar({
                duration = Config.BandageTime,
                position = 'bottom',
                useWhileDead = false,
                canCancel = false,
                disableControl = true,
                disable = {
                    move = true,
                    mouse = true,
                },
                anim = {
                    dict = 'mini_games@story@mob4@heal_jules@bandage@arthur',
                    clip = 'bandage_fast',
                    flag = 1,
                },
                label = string.format("Applying %s...", bandageConfig.label),
            })

            -- Apply bandage using new system
            local success = ApplyBandage(targetBodyPart, bandageType, GetPlayerServerId(PlayerId()))
            
            if success then
                TriggerServerEvent('QC-AdvancedMedic:server:removeitem', itemName, 1)
            else
                lib.notify({
                    title = locale('cl_menu_treatment_failed'),
                    description = locale('cl_desc_bandage_failed'),
                    type = 'error',
                    duration = 5000
                })
            end

            LocalPlayer.state:set('inv_busy', false, true)
            isBusy = false
        else
            lib.notify({
                title = locale('cl_error'),
                description = string.format(locale('cl_desc_fmt_no_item_available'), bandageConfig.label),
                type = 'error',
                duration = 5000
            })
        end
    else
        lib.notify({ title = locale('cl_error'), description = locale('cl_error_c'), type = 'error', duration = 5000 })
    end
end)

---------------------------------------------------------------------
-- cleanup
---------------------------------------------------------------------
AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Stop pain sounds when resource stops
    PlayPain(cache.ped, 4, 1, true, true)

    DestroyAllCams(true)

    for i = 1, #createdEntries do
        if createdEntries[i].type == "BLIP" then
            if createdEntries[i].handle then
                RemoveBlip(createdEntries[i].handle)
            end
        end

        if createdEntries[i].type == "PROMPT" then
            if createdEntries[i].handle then
                exports['rsg-core']:deletePrompt(createdEntries[i].handle)
            end
        end
    end
end)

---------------------------------------------------------------------
-- medical data persistence
---------------------------------------------------------------------

-- Load medical data on resource start (for script restarts)
CreateThread(function()
    Wait(2000) -- Wait for core systems to initialize
    
    if LocalPlayer.state.isLoggedIn then
        TriggerServerEvent('QC-AdvancedMedic:server:LoadMedicalData')
        if Config.WoundSystem.debugging.enabled then
            print("[PERSISTENCE] Loading medical data on resource start...")
        end
    end
    
    -- Initialize body part health system
    if InitializeBodyPartHealth then
        InitializeBodyPartHealth()
        if Config.WoundSystem.debugging.enabled then
            print("[BODY HEALTH] Body part health system initialized")
        end
    end
end)

-- Load medical data when player spawns
AddEventHandler('playerSpawned', function()
    Wait(1000) -- Wait a moment for spawn to complete
    TriggerServerEvent('QC-AdvancedMedic:server:LoadMedicalData')
    if Config.WoundSystem.debugging.enabled then
        print("[PERSISTENCE] Loading medical data on player spawn...")
    end
end)

---------------------------------------------------------------------
-- developer commands for testing
---------------------------------------------------------------------

---------------------------------------------------------------------
-- /checkhealth command - Show self medical NUI with scripted camera
---------------------------------------------------------------------
local checkhealthCam = nil

RegisterCommand('checkhealth', function()
    local player = RSGCore.Functions.GetPlayerData()
    if not player then return end

    -- Get current medical data including body part health (direct access since same resource)
    local bodyPartHealth = GetBodyPartHealthData()
    local wounds = PlayerWounds or {}
    local treatments = {}
    local infections = PlayerInfections or {}

    -- Convert ActiveTreatments object to array for NUI compatibility
    if ActiveTreatments then
        for bodyPart, treatment in pairs(ActiveTreatments) do
            table.insert(treatments, {
                bodyPart = bodyPart,
                type = treatment.treatmentType,
                itemType = treatment.itemType,
                appliedTime = treatment.appliedTime,
                effectiveness = treatment.effectiveness,
                appliedBy = treatment.appliedBy
            })
        end
    end

    -- Get player inventory for bandages
    local inventory = {}
    if Config.BandageTypes then
        for bandageKey, bandageData in pairs(Config.BandageTypes) do
            local hasItem = RSGCore.Functions.HasItem(bandageData.itemName, 1)
            if hasItem then
                inventory[bandageData.itemName] = 1 -- Just mark as available
            end
        end
    end

    -- Prepare data for self-examination NUI
    local selfMedicalData = {
        playerName = player.charinfo.firstname .. " " .. player.charinfo.lastname,
        playerId = player.citizenid,
        wounds = wounds,
        treatments = treatments,
        infections = infections,
        bodyPartHealth = bodyPartHealth,
        injuryStates = Config.InjuryStates,
        infectionStages = Config.InfectionSystem and Config.InfectionSystem.stages or {},
        bodyParts = Config.BodyParts,
        uiColors = Config.UI.colors,
        inventory = inventory,
        bandageTypes = Config.BandageTypes or {},
        isSelfExamination = true, -- Flag to indicate this is self-examination
        translations = Config.Strings or {}
    }

    -- Create scripted camera positioned in front of player
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local pedHeading = GetEntityHeading(ped)

    -- Calculate camera position in front of player (2.5 meters forward, 0.5 meters up, slight offset to the side)
    local forwardX = pedCoords.x + (math.sin(math.rad(pedHeading)) * -2.5)
    local forwardY = pedCoords.y + (math.cos(math.rad(pedHeading)) * 2.5)
    local camCoords = vector3(forwardX, forwardY, pedCoords.z + 0.5)

    -- Create camera
    checkhealthCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(checkhealthCam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtEntity(checkhealthCam, ped, 0.0, 0.0, 0.0, true)
    SetCamActive(checkhealthCam, true)
    RenderScriptCams(true, true, 500, true, true)

    -- Show medical panel NUI
    SetNuiFocus(true, true)
    SetCursorLocation(0.5, 0.5)

    SendNUIMessage({
        type = 'show-medical-panel',
        data = selfMedicalData
    })

    lib.notify({
        title = locale('cl_self_examination'),
        description = locale('cl_examining_condition'),
        type = 'inform',
        duration = 3000
    })

end, false)

-- NUI Callback to close medical panel and disable focus
RegisterNUICallback('close-medical-panel', function(data, cb)
    SetNuiFocus(false, false)

    -- Destroy checkhealth camera if it exists
    if checkhealthCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(checkhealthCam, false)
        checkhealthCam = nil
    end

    cb({status = 'ok'})

    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        print("^3[MEDICAL NUI] Medical panel closed, NUI focus disabled, camera destroyed^7")
    end
end)

-- NUI Callback to get current inventory and wounds (real-time check)
RegisterNUICallback('get-current-inventory', function(data, cb)
    local inventory = {
        bandages = {},
        tourniquets = {},
        medicines = {},
        injections = {}
    }

    -- Check all bandage types
    if Config.BandageTypes then
        for bandageKey, bandageData in pairs(Config.BandageTypes) do
            local hasItem = RSGCore.Functions.HasItem(bandageData.itemName, 1)
            if hasItem then
                table.insert(inventory.bandages, {
                    key = bandageKey,
                    itemName = bandageData.itemName,
                    label = bandageData.label or bandageKey,
                    hasItem = true
                })
            end
        end
    end

    -- Check all tourniquet types
    if Config.TourniquetTypes then
        for tourniquetKey, tourniquetData in pairs(Config.TourniquetTypes) do
            local hasItem = RSGCore.Functions.HasItem(tourniquetData.itemName, 1)
            if hasItem then
                table.insert(inventory.tourniquets, {
                    key = tourniquetKey,
                    itemName = tourniquetData.itemName,
                    label = tourniquetData.label or tourniquetKey,
                    hasItem = true
                })
            end
        end
    end

    -- Get current active wounds (exclude scars)
    local wounds = {}
    if PlayerWounds then
        for bodyPart, wound in pairs(PlayerWounds) do
            if not wound.isScar then
                wounds[bodyPart] = {
                    painLevel = wound.painLevel or 0,
                    bleedingLevel = wound.bleedingLevel or 0,
                    healthPercentage = wound.healthPercentage or 100,
                    metadata = wound.metadata
                }
            end
        end
    end

    cb({
        inventory = inventory,
        wounds = wounds
    })

    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        local woundCount = 0
        for _ in pairs(wounds) do woundCount = woundCount + 1 end
        print(string.format("^2[INVENTORY CHECK] Bandages: %d, Tourniquets: %d, Wounds: %d^7",
            #inventory.bandages, #inventory.tourniquets, woundCount))
    end
end)

-- Handle bandage application from NUI
RegisterNUICallback('apply-bandage', function(data, cb)
    local bodyPart = data.bodyPart
    local bandageType = data.bandageType
    
    if not bodyPart or not bandageType then
        cb({status = 'error', message = 'Missing body part or bandage type'})
        return
    end
    
    -- Map NUI bandage type to config key and get config
    local configBandageType = nil
    local bandageConfig = nil
    for bType, bData in pairs(Config.BandageTypes or {}) do
        if bData.itemName == bandageType then
            configBandageType = bType
            bandageConfig = bData
            break
        end
    end
    
    if not configBandageType or not bandageConfig then
        cb({status = 'error', message = 'Invalid bandage type'})
        return
    end
    
    -- Check if player has the bandage item
    local hasItem = RSGCore.Functions.HasItem(bandageType, 1)
    if not hasItem then
        lib.notify({
            title = locale('cl_menu_medical_error'),
            description = locale('cl_desc_no_bandage_inventory'),
            type = 'error',
            duration = 3000
        })
        cb({status = 'error', message = 'Item not found'})
        return
    end
    
    -- Check if already busy
    if isBusy then
        cb({status = 'error', message = 'Already applying treatment'})
        return
    end
    
    -- Set busy state and progress bar like regular bandage system
    isBusy = true
    LocalPlayer.state:set('inv_busy', true, true)
    SetCurrentPedWeapon(cache.ped, GetHashKey('weapon_unarmed'))
    
    -- Start progress bar with same settings as regular bandage system
    lib.progressBar({
        duration = Config.BandageTime,
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disableControl = true,
        disable = {
            move = true,
            mouse = true,
        },
        anim = {
            dict = 'mini_games@story@mob4@heal_jules@bandage@arthur',
            clip = 'bandage_fast',
            flag = 1,
        },
        label = string.format("Applying %s to %s...", bandageConfig.label, bodyPart:lower()),
    })
    
    -- Apply bandage using proper treatment system after progress completes
    local appliedBy = GetPlayerServerId(PlayerId())
    local success = exports['QC-AdvancedMedic']:ApplyBandage(bodyPart:upper(), configBandageType, appliedBy)
    
    if success then
        -- Remove item from inventory like regular system
        TriggerServerEvent('QC-AdvancedMedic:server:removeitem', bandageConfig.itemName, 1)
        
        -- IMMEDIATELY update NUI with new treatment data before responding to callback
        local updatedBodyPartHealth = GetBodyPartHealthData()
        local updatedWounds = PlayerWounds or {}
        local updatedTreatments = {}
        local updatedInfections = PlayerInfections or {}
        
        -- Convert ActiveTreatments to array immediately after application
        if ActiveTreatments then
            for bodyPartKey, treatment in pairs(ActiveTreatments) do
                table.insert(updatedTreatments, {
                    bodyPart = bodyPartKey,
                    type = treatment.treatmentType,
                    itemType = treatment.itemType,
                    appliedTime = treatment.appliedTime,
                    effectiveness = treatment.effectiveness,
                    appliedBy = treatment.appliedBy
                })
            end
        end
        
        -- Update NUI immediately
        SendNUIMessage({
            type = 'update-medical-data',
            data = {
                wounds = updatedWounds,
                treatments = updatedTreatments,
                infections = updatedInfections,
                bodyPartHealth = updatedBodyPartHealth
            }
        })
        
        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
            print(string.format("^2[IMMEDIATE UPDATE] Applied bandage and updated NUI with %d treatments^7", #updatedTreatments))
        end
        
        cb({status = 'ok', treatments = updatedTreatments}) -- Respond with updated data
    else
        lib.notify({
            title = locale('cl_menu_application_failed'),
            description = string.format(locale('cl_desc_fmt_bandage_apply_failed'), bodyPart:lower()),
            type = 'error',
            duration = 3000
        })
        cb({status = 'error', message = 'Bandage application failed'})
    end
    
    -- Clear busy state
    isBusy = false
    LocalPlayer.state:set('inv_busy', false, true)
    
    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        print("^3[BANDAGE NUI] Applied " .. configBandageType .. " on " .. bodyPart .. "^7")
    end
end)

-- Handle tourniquet application from NUI
RegisterNUICallback('apply-tourniquet', function(data, cb)
    local bodyPart = data.bodyPart
    local tourniquetType = data.tourniquetType
    
    if not bodyPart or not tourniquetType then
        cb({status = 'error', message = 'Missing body part or tourniquet type'})
        return
    end
    
    -- Check if player has the tourniquet item
    local hasItem = RSGCore.Functions.HasItem(tourniquetType, 1)
    if not hasItem then
        lib.notify({
            title = locale('cl_menu_medical_error'),
            description = locale('cl_desc_no_tourniquet_inventory'),
            type = 'error',
            duration = 3000
        })
        cb({status = 'error', message = 'Item not found'})
        return
    end
    
    -- Check if already busy
    if isBusy then
        cb({status = 'error', message = 'Already applying treatment'})
        return
    end
    
    -- Set busy state
    isBusy = true
    LocalPlayer.state:set('inv_busy', true, true)
    SetCurrentPedWeapon(cache.ped, GetHashKey('weapon_unarmed'))
    
    -- Start progress bar for tourniquet application
    lib.progressBar({
        duration = 5000, -- 5 seconds for emergency tourniquet
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disableControl = true,
        disable = {
            move = true,
            mouse = true,
        },
        anim = {
            dict = 'mini_games@story@mob4@heal_jules@bandage@arthur',
            clip = 'bandage_fast',
            flag = 1,
        },
        label = string.format("Applying emergency tourniquet to %s...", bodyPart:lower()),
    })
    
    -- Apply tourniquet using treatment system
    local appliedBy = GetPlayerServerId(PlayerId())
    local success = exports['QC-AdvancedMedic']:ApplyTourniquet(bodyPart:upper(), tourniquetType, appliedBy)
    
    if success then
        -- Remove item from inventory
        TriggerServerEvent('QC-AdvancedMedic:server:removeitem', tourniquetType, 1)
        
        -- IMMEDIATELY update NUI with new treatment data
        local updatedBodyPartHealth = GetBodyPartHealthData()
        local updatedWounds = PlayerWounds or {}
        local updatedTreatments = {}
        local updatedInfections = PlayerInfections or {}
        
        -- Convert ActiveTreatments to array immediately after application
        if ActiveTreatments then
            for bodyPartKey, treatment in pairs(ActiveTreatments) do
                table.insert(updatedTreatments, {
                    bodyPart = bodyPartKey,
                    type = treatment.treatmentType,
                    itemType = treatment.itemType,
                    appliedTime = treatment.appliedTime,
                    effectiveness = treatment.effectiveness,
                    appliedBy = treatment.appliedBy
                })
            end
        end
        
        -- Update NUI immediately
        SendNUIMessage({
            type = 'update-medical-data',
            data = {
                wounds = updatedWounds,
                treatments = updatedTreatments,
                infections = updatedInfections,
                bodyPartHealth = updatedBodyPartHealth
            }
        })
        
        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
            print(string.format("^2[IMMEDIATE UPDATE] Applied tourniquet and updated NUI with %d treatments^7", #updatedTreatments))
        end
        
        cb({status = 'ok', treatments = updatedTreatments})
    else
        lib.notify({
            title = locale('cl_menu_application_failed'),
            description = string.format(locale('cl_desc_fmt_tourniquet_apply_failed'), bodyPart:lower()),
            type = 'error',
            duration = 3000
        })
        cb({status = 'error', message = 'Tourniquet application failed'})
    end
    
    -- Clear busy state
    isBusy = false
    LocalPlayer.state:set('inv_busy', false, true)
    
    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        print("^3[TOURNIQUET NUI] Applied " .. tourniquetType .. " on " .. bodyPart .. "^7")
    end
end)


-- Handle treatment removal from NUI
RegisterNUICallback('remove-treatment', function(data, cb)
    local bodyPart = data.bodyPart
    local treatmentType = data.treatmentType
    
    if not bodyPart or not treatmentType then
        cb({status = 'error', message = 'Missing body part or treatment type'})
        return
    end
    
    -- Use the existing removebandage command flow
    if treatmentType == 'bandage' then
        TriggerServerEvent('QC-AdvancedMedic:server:removebandage', bodyPart:upper())

        lib.notify({
            title = locale('cl_menu_treatment_removed'),
            description = string.format(locale('cl_desc_fmt_bandage_removed'), bodyPart:lower()),
            type = 'success',
            duration = 3000
        })
    end
    
    cb({status = 'ok'})
    
    -- Refresh medical panel data after treatment removal
    CreateThread(function()
        Wait(2000) -- Wait for server processing
        
        -- Request fresh medical data from server
        TriggerServerEvent('QC-AdvancedMedic:server:LoadMedicalData')
        Wait(500) -- Wait for server response
        
        -- Get updated medical data
        local updatedBodyPartHealth = GetBodyPartHealthData()
        local updatedWounds = PlayerWounds or {}
        local updatedTreatments = {}
        local updatedInfections = PlayerInfections or {}
        
        -- Convert ActiveTreatments to array
        if ActiveTreatments then
            for bodyPartKey, treatment in pairs(ActiveTreatments) do
                table.insert(updatedTreatments, {
                    bodyPart = bodyPartKey,
                    type = treatment.treatmentType,
                    itemType = treatment.itemType,
                    appliedTime = treatment.appliedTime,
                    effectiveness = treatment.effectiveness,
                    appliedBy = treatment.appliedBy
                })
            end
        end
        
        -- Update NUI with fresh data
        SendNUIMessage({
            type = 'update-medical-data',
            data = {
                wounds = updatedWounds,
                treatments = updatedTreatments,
                infections = updatedInfections,
                bodyPartHealth = updatedBodyPartHealth
            }
        })
    end)
    
    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        print("^3[TREATMENT NUI] Removed " .. treatmentType .. " from " .. bodyPart .. "^7")
    end
end)

-- Handle treatment replacement from NUI
RegisterNUICallback('replace-treatment', function(data, cb)
    local bodyPart = data.bodyPart
    local treatmentType = data.treatmentType
    
    if not bodyPart or not treatmentType then
        cb({status = 'error', message = 'Missing body part or treatment type'})
        return
    end
    
    -- For replace, we first remove the current treatment and then trigger the bandage panel
    if treatmentType == 'bandage' then
        -- Remove current bandage
        TriggerServerEvent('QC-AdvancedMedic:server:removebandage', bodyPart:upper())
        
        -- Wait a moment then trigger bandage selection
        CreateThread(function()
            Wait(500)
            
            -- Check if player has bandages available
            local hasAnyBandage = false
            if Config.BandageTypes then
                for bandageKey, bandageData in pairs(Config.BandageTypes) do
                    local hasItem = RSGCore.Functions.HasItem(bandageData.itemName, 1)
                    if hasItem then
                        hasAnyBandage = true
                        break
                    end
                end
            end
            
            if hasAnyBandage then
                lib.notify({
                    title = locale('cl_menu_bandage_removed'),
                    description = string.format(locale('cl_desc_fmt_bandage_old_removed'), bodyPart:lower()),
                    type = 'inform',
                    duration = 5000
                })
            else
                lib.notify({
                    title = locale('cl_menu_no_bandages_available'),
                    description = locale('cl_desc_need_bandages_replace'),
                    type = 'error',
                    duration = 4000
                })
            end
        end)
    end
    
    cb({status = 'ok'})
    
    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        print("^3[TREATMENT NUI] Initiated replacement for " .. treatmentType .. " on " .. bodyPart .. "^7")
    end
end)

-- Handle refresh medical data request from NUI
RegisterNUICallback('refresh-medical-data', function(data, cb)
    -- Request fresh medical data from server first
    TriggerServerEvent('QC-AdvancedMedic:server:LoadMedicalData')
    
    CreateThread(function()
        Wait(500) -- Wait for server response
        
        -- Get current medical data (should now be fresh from server)
        local updatedBodyPartHealth = GetBodyPartHealthData()
        local updatedWounds = PlayerWounds or {}
        local updatedTreatments = {}
        local updatedInfections = PlayerInfections or {}
    
        -- Convert ActiveTreatments to array
        if ActiveTreatments then
            for bodyPartKey, treatment in pairs(ActiveTreatments) do
                table.insert(updatedTreatments, {
                    bodyPart = bodyPartKey,
                    type = treatment.treatmentType,
                    itemType = treatment.itemType,
                    appliedTime = treatment.appliedTime,
                    effectiveness = treatment.effectiveness,
                    appliedBy = treatment.appliedBy
                })
            end
        end
        
        -- Update NUI with fresh data
        SendNUIMessage({
            type = 'update-medical-data',
            data = {
                wounds = updatedWounds,
                treatments = updatedTreatments,
                infections = updatedInfections,
                bodyPartHealth = updatedBodyPartHealth
            }
        })
        
        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
            print("^2[REFRESH] Medical data refreshed manually from NUI^7")
        end
    end)
    
    cb({status = 'ok'})
end)

-- Test command to add fake treatment for debugging
RegisterCommand('addtreatment', function(source, args)
    local bodyPart = args[1] or 'HEAD'
    local treatmentType = args[2] or 'bandage'
    local itemType = args[3] or 'cotton_bandage'
    
    -- Add fake treatment for testing
    ActiveTreatments[bodyPart] = {
        treatmentType = treatmentType,
        itemType = itemType,
        appliedTime = GetGameTimer(),
        effectiveness = 100,
        appliedBy = 'Self'
    }
    
    lib.notify({
        title = locale('cl_menu_test_treatment_added'),
        description = string.format(locale('cl_desc_fmt_added_treatment_test'), treatmentType, bodyPart),
        type = 'success',
        duration = 3000
    })
    
    print("^2[TEST] Added treatment: " .. treatmentType .. " to " .. bodyPart .. "^7")
end, false)

-- Test command to directly show inspection panel
RegisterCommand('testnui', function()
    SetNuiFocus(true, true)
    SetCursorLocation(0.5, 0.5)
    
    local testData = {
        playerName = "Test Player",
        playerId = "TEST123",
        wounds = {
            larm = { health = 50, painLevel = 2, bleedingLevel = 1 }
        },
        treatments = {},
        infections = {},
        injuryStates = Config.InjuryStates,
        uiColors = Config.UI.colors
    }
    
    SendNUIMessage({
        type = 'show-inspection-panel',
        data = testData
    })
    
    print("^2[TEST NUI] Sent test inspection panel message")
end, false)

-- Test command to hide NUI
RegisterCommand('hidenui', function()
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'hide-all'
    })
    print("^2[TEST NUI] Hidden NUI")
end, false)

-- Developer command to force infection for testing
RegisterCommand('forceinfection', function(source, args)
    if not Config.InfectionSystem.debugging.enabled then
        lib.notify({
            title = locale('cl_menu_command_disabled'),
            description = locale('cl_desc_dev_commands_debug'),
            type = 'error',
            duration = 5000
        })
        return
    end

    local bodyPart = args[1] or 'UPPER_BODY'
    local stage = tonumber(args[2]) or 1
    
    -- Validate body part
    if not Config.BodyParts[bodyPart] then
        lib.notify({
            title = locale('cl_menu_invalid_body_part'),
            description = string.format(locale('cl_desc_fmt_body_part_not_found'), bodyPart),
            type = 'error',
            duration = 8000
        })
        return
    end
    
    -- Validate stage
    if stage < 1 or stage > #Config.InfectionSystem.stages then
        lib.notify({
            title = locale('cl_menu_invalid_stage'),
            description = string.format(locale('cl_desc_fmt_stage_must_be_between'), #Config.InfectionSystem.stages),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Force create infection
    CreateForceInfection(bodyPart, stage)
    
    lib.notify({
        title = locale('cl_menu_developer_command'),
        description = string.format(locale('cl_desc_fmt_forced_infection'),
            Config.InfectionSystem.stages[stage].name, bodyPart, stage),
        type = 'inform',
        duration = 6000
    })
    
    print(string.format("[DEV COMMAND] Forced infection: %s stage %d", bodyPart, stage))
end)

-- Developer command to list current infections
RegisterCommand('listinfections', function()
    if not Config.InfectionSystem.debugging.enabled then
        lib.notify({
            title = locale('cl_menu_command_disabled'),
            description = locale('cl_desc_dev_commands_debug'),
            type = 'error',
            duration = 5000
        })
        return
    end

    local infections = GetInfectionData()
    local count = 0
    
    print("=== CURRENT INFECTIONS ===")
    for bodyPart, infection in pairs(infections) do
        count = count + 1
        local stageName = Config.InfectionSystem.stages[infection.stage] and Config.InfectionSystem.stages[infection.stage].name or "Unknown"
        print(string.format("%s: Stage %d (%s)", bodyPart, infection.stage, stageName))
        
        local cureProgress = GetCureProgress(bodyPart) or 0
        if cureProgress > 0 then
            print(string.format("  Cure Progress: %.1f%%", cureProgress))
        end
    end
    
    if count == 0 then
        print("No active infections")
    else
        print(string.format("Total: %d active infections", count))
    end
    print("========================")
    
    lib.notify({
        title = locale('cl_menu_infection_list'),
        description = string.format(locale('cl_desc_fmt_found_infections_console'), count),
        type = 'inform',
        duration = 5000
    })
end)

-- Use Bandage Command: /usebandage [bandageType] [bodyPart] 
-- This command uses the same event flow as useable items for production reliability
RegisterCommand('usebandage', function(source, args)
    if #args < 2 then
        lib.notify({
            title = locale('cl_menu_usage'),
            description = locale('cl_desc_usebandage_help'),
            type = 'inform',
            duration = 8000
        })
        return
    end
    
    local bandageType = string.lower(args[1])
    local bodyPart = string.upper(args[2])
    
    -- Validate bandage type
    if not Config.BandageTypes[bandageType] then
        local availableTypes = {}
        for bType, _ in pairs(Config.BandageTypes) do
            table.insert(availableTypes, bType)
        end
        
        lib.notify({
            title = locale('cl_menu_invalid_bandage_type'),
            description = string.format(locale('cl_desc_fmt_available_types'), table.concat(availableTypes, ", ")),
            type = 'error',
            duration = 6000
        })
        return
    end
    
    -- Validate body part
    if not Config.BodyParts[bodyPart] then
        local availableParts = {}
        for part, config in pairs(Config.BodyParts) do
            table.insert(availableParts, part)
        end

        lib.notify({
            title = locale('cl_menu_invalid_body_part'),
            description = string.format(locale('cl_desc_fmt_available_parts'), table.concat(availableParts, ", ")),
            type = 'error',
            duration = 8000
        })
        return
    end

    -- Trigger the same event flow as useable bandage items
    -- Store the target body part for the bandage system to use
    targetBodyPartOverride = bodyPart
    TriggerEvent('QC-AdvancedMedic:client:usebandage', bandageType)
end)

-- Remove Bandage Command: /removebandage [bodyPart]
RegisterCommand('removebandage', function(source, args)
    if #args < 1 then
        lib.notify({
            title = locale('cl_menu_usage'),
            description = locale('cl_desc_removebandage_help'),
            type = 'inform',
            duration = 5000
        })
        return
    end
    
    local bodyPart = string.upper(args[1])
    
    -- Validate body part
    if not Config.BodyParts[bodyPart] then
        local availableParts = {}
        for part, config in pairs(Config.BodyParts) do
            table.insert(availableParts, part)
        end

        lib.notify({
            title = locale('cl_menu_invalid_body_part'),
            description = string.format(locale('cl_desc_fmt_available_parts'), table.concat(availableParts, ", ")),
            type = 'error',
            duration = 8000
        })
        return
    end

    -- Check if body part has a bandage
    local activeTreatments = ActiveTreatments or {}
    if not activeTreatments[bodyPart] or activeTreatments[bodyPart].treatmentType ~= "bandage" then
        lib.notify({
            title = locale('cl_menu_no_bandage'),
            description = string.format(locale('cl_desc_fmt_no_bandage_found'), Config.BodyParts[bodyPart].label),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Remove the bandage
    RemoveTreatment(bodyPart, "bandage")

    lib.notify({
        title = locale('cl_menu_bandage_removed'),
        description = string.format(locale('cl_desc_fmt_removed_bandage'), Config.BodyParts[bodyPart].label),
        type = 'success',
        duration = 5000
    })
    
    print(string.format("[BANDAGE] Removed bandage from %s", Config.BodyParts[bodyPart].label))
end)

