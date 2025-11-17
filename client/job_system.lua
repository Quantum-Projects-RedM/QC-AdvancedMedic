local RSGCore = exports['rsg-core']:GetCoreObject()
local blipEntries = {}
local transG = Config.DeathTimer

-- Debug ConfigMissions loading
Citizen.CreateThread(function()
    Citizen.Wait(1000) -- Wait for configs to load
    if ConfigMissions then
        print("^2SUCCESS: ConfigMissions loaded successfully^7")
        if ConfigMissions.MedicMissions then
            print("^2SUCCESS: Found", #ConfigMissions.MedicMissions, "medic missions^7")
        end
    else
        print("^1ERROR: ConfigMissions is still nil after resource start^7")
    end
end)

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

-- Toggle On-Duty
AddEventHandler('QC-AdvancedMedic:client:ToggleDuty', function()
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        if not IsPlayerMedic() then
            lib.notify({ title = locale('cl_not_medic'), type = 'error', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake', duration = 7000 })
            return
        end

        TriggerServerEvent("RSGCore:ToggleDuty")
    end)
end)

-- Medic Revive Player
AddEventHandler('QC-AdvancedMedic:client:RevivePlayer', function()
    local hasItem = RSGCore.Functions.HasItem('firstaid', 1)
    local ped = PlayerPedId()
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
        anim = {
            dict = 'mini_games@story@mob4@heal_jules@bandage@arthur',
            clip = 'bandage_fast'
        },
        label = locale('cl_reviving'),
    })
    ClearPedTasks(cache.ped)
    FreezeEntityPosition(cache.ped, false)
    TriggerServerEvent('QC-AdvancedMedic:server:RevivePlayer', playerId)
    -- NOTE: Wounds persist through medic revive - use treat wounds or /clearwounds to clear them
    transG = 0

end)

-- Medic Treat Wounds
AddEventHandler('QC-AdvancedMedic:client:TreatWounds', function()
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
    TriggerServerEvent('QC-AdvancedMedic:server:TreatWounds', playerId)
    TriggerEvent('QC-AdvancedMedic:ResetLimbs', playerId)
    transG = 0

end)

-- Medic Treat Wounds
RegisterNetEvent('QC-AdvancedMedic:client:HealInjuries', function()
    SetAttributeCoreValue(cache.ped, 0, 100)
    SetAttributeCoreValue(cache.ped, 1, 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "hunger", RSGCore.Functions.GetPlayerData().metadata["hunger"] + 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "thirst", RSGCore.Functions.GetPlayerData().metadata["thirst"] + 100)
    ClearPedBloodDamage(cache.ped)
end)

-- Medic Alert
RegisterNetEvent('QC-AdvancedMedic:client:medicAlert', function(coords, text)
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

---------------------------------------------------------------------
-- MEDIC MISSION SYSTEM
---------------------------------------------------------------------
local medicMissionActive = false
local medicMissionData = nil
local medicMissionPed = nil
local medicMissionBlip = nil
local missionPatientTransported = false
local surgeryInProgress = false
local currentMissionStep = 0
local missionStepData = {}
local transportVehicle = nil

-- Miss from the menu
RegisterNetEvent('QC-AdvancedMedic:client:startMission', function()

    if medicMissionActive then
        lib.notify({ title = locale('cl_mission_active'), type = 'error', duration = 5000 })
        return
    end
    
    if not Config.EnableMedicMissions or not ConfigMissions.MedicMissions or #ConfigMissions.MedicMissions == 0 then
        lib.notify({ title = locale('cl_no_missions'), type = 'error', duration = 5000 })
        print("^3DEBUG: Config.EnableMedicMissions:", Config.EnableMedicMissions, "ConfigMissions.MedicMissions:", ConfigMissions.MedicMissions and "exists" or "nil")
        return
    end
    -- Get player's job to determine available locations
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local playerJob = PlayerData.job.name
    
    -- Find matching location group for the player's job
    local availableLocations = {}
    for locationName, locationData in pairs(ConfigMissions.Locations) do
        if locationData.job == playerJob then
            availableLocations = locationData.locations
            break
        end
    end
    
    -- If no job-specific locations found, return error
    if #availableLocations == 0 then
        lib.notify({ title = locale('cl_no_missions_job'), type = 'error', duration = 5000 })
        return
    end
    
    -- Choose a random mission and random location
    print("^3DEBUG: Total available missions:", #ConfigMissions.MedicMissions)
    local missionId = math.random(1, #ConfigMissions.MedicMissions)
    print("^3DEBUG: Selected mission ID:", missionId)
    local randomLocation = availableLocations[math.random(1, #availableLocations)]
    medicMissionData = ConfigMissions.MedicMissions[missionId]
    medicMissionActive = true
    
    -- Add the location to mission data
    medicMissionData.coords = randomLocation
    
    -- Expand simplified wound config into full wound structure
    local currentTime = GetGameTimer()
    for bodyPart, woundData in pairs(medicMissionData.patientData.wounds) do
        -- Get injury state descriptions from Config.InjuryStates
        local painState = Config.InjuryStates[woundData.painLevel] or Config.InjuryStates[1]
        local bleedingState = Config.InjuryStates[woundData.bleedingLevel] or Config.InjuryStates[1]
        
        -- Build full wound structure from simplified config
        local fullWound = {
            painLevel = woundData.painLevel,
            bleedingLevel = woundData.bleedingLevel,
            currentHealth = math.floor(woundData.healthPercentage),
            maxHealth = 100,
            healthPercentage = woundData.healthPercentage,
            weaponData = Config.WeaponDamage[GetHashKey(woundData.weaponClass)] and Config.WeaponDamage[GetHashKey(woundData.weaponClass)].data or 'Unknown',
            timestamp = currentTime,
            isScar = false,
            scarTime = nil,
            -- Add injury state descriptions for medical assessment
            painDescription = painState.pain,
            bleedingDescription = bleedingState.bleeding,
            urgency = math.max(woundData.painLevel, woundData.bleedingLevel) <= 3 and painState.urgency or bleedingState.urgency,
            treatmentRecommendation = bleedingState.unifiedDesc,
            metadata = {
                weaponClass = woundData.weaponClass,
                weaponHash = GetHashKey(woundData.weaponClass),
                ballisticType = Config.WeaponDamage[GetHashKey(woundData.weaponClass)] and Config.WeaponDamage[GetHashKey(woundData.weaponClass)].ballisticType or 'unknown',
                status = Config.WeaponDamage[GetHashKey(woundData.weaponClass)] and Config.WeaponDamage[GetHashKey(woundData.weaponClass)].status or 'wound',
                weaponType = Config.WeaponDamage[GetHashKey(woundData.weaponClass)] and Config.WeaponDamage[GetHashKey(woundData.weaponClass)].data or 'Unknown',
                requiresSurgery = woundData.requiresSurgery or false,
                description = woundData.description,
                -- Add medical assessment descriptions
                painAssessment = painState.pain,
                bleedingAssessment = bleedingState.bleeding,
                clinicalUrgency = math.max(woundData.painLevel, woundData.bleedingLevel) <= 3 and painState.urgency or bleedingState.urgency,
                recommendedTreatment = bleedingState.unifiedDesc
            },
            treatments = {},
            infections = {}
        }
        medicMissionData.patientData.wounds[bodyPart] = fullWound
    end
    
    -- Create NPC and Blip using the selected location
    local coords = medicMissionData.coords
    
    print(string.format("^2[MISSION] Starting mission %d: %s at %s location (Job: %s)^7", missionId, medicMissionData.patientData.playerName, tostring(randomLocation), playerJob))
    local pedModel = GetHashKey(medicMissionData.pedModel)
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do Wait(0) end
    medicMissionPed = CreatePed(pedModel, coords.x, coords.y, coords.z - 1.0, coords.w, false, false, 0, 0)
    while not DoesEntityExist(medicMissionPed) do Wait(0) end
    ClearPedTasks(medicMissionPed)
    ClearPedSecondaryTask(medicMissionPed)
    SetRandomOutfitVariation(medicMissionPed, true)
    TaskSetBlockingOfNonTemporaryEvents(medicMissionPed, true)
    SetPedFleeAttributes(medicMissionPed, 0, 0)
    SetPedCombatAttributes(medicMissionPed, 17, 1)
    SetPedSeeingRange(medicMissionPed, 0.0)
    SetPedHearingRange(medicMissionPed, 0.0)
    SetPedKeepTask(medicMissionPed, true)
    FreezeEntityPosition(medicMissionPed, true)
    SetEntityVisible(medicMissionPed, true)

    -- After creating and freezing the NPC, play the collapse animation from config
    if medicMissionData.animDict and medicMissionData.animName then
        RequestAnimDict(medicMissionData.animDict)
        while not HasAnimDictLoaded(medicMissionData.animDict) do Wait(0) end
        TaskPlayAnim(medicMissionPed, medicMissionData.animDict, medicMissionData.animName, 8.0, -8.0, -1, 1, 0, false, false, false)
    end

    -- Blip
    medicMissionBlip = BlipAddForCoords(1664425300, coords.x, coords.y, coords.z)
    SetBlipSprite(medicMissionBlip, GetHashKey(medicMissionData.blipSprite), true)
    SetBlipScale(medicMissionBlip, 0.2)
    SetBlipName(medicMissionBlip, medicMissionData.blipName)
    -- GPS leads to a mission
    if Config.AddGPSRoute then
        ClearGpsMultiRoute()
        StartGpsMultiRoute(6, true, true)
        AddPointToGpsMultiRoute(coords.x, coords.y, coords.z)
        SetGpsMultiRouteRender(true)
    end
    -- QTarget zona (ox_target)
    exports.ox_target:addLocalEntity(medicMissionPed, {
        {
            name = 'medic_mission_heal',
            icon = 'fa-solid fa-kit-medical',
            label = 'Inspect and treat patient',
            canInteract = function(entity, distance, coords, name)
                return distance < 2.0 and medicMissionActive
            end,
            onSelect = function()
                TriggerEvent('QC-AdvancedMedic:client:inspectMissionPed')
            end
        }
    })
    lib.notify({ title = locale('mission_title'), description = string.format(locale('cl_mission_gps_set'), tostring(missionId)), type = 'inform', duration = 9000 })
end)

-- New mission inspection system that shows medical data
RegisterNetEvent('QC-AdvancedMedic:client:inspectMissionPed', function()
    if not medicMissionActive or not medicMissionPed or not medicMissionData then return end
    
    -- Use the new patientData structure (same format as player inspections)
    local inspectionData = {
        playerName = medicMissionData.patientData.playerName,
        citizenid = medicMissionData.patientData.citizenid,
        source = medicMissionData.patientData.source,
        playerId = medicMissionData.patientData.source, -- NUI needs this for medicine application (-1 for NPCs)
        bloodLevel = medicMissionData.patientData.bloodLevel,
        isBleeding = medicMissionData.patientData.isBleeding,
        wounds = medicMissionData.patientData.wounds or {},
        treatments = medicMissionData.patientData.treatments or {},
        infections = medicMissionData.patientData.infections or {},
        bandages = medicMissionData.patientData.bandages or {},
        healthData = medicMissionData.patientData.healthData or {},
        description = medicMissionData.patientData.description,
        difficulty = medicMissionData.patientData.difficulty
    }
    
    -- Use NUI inspection panel instead of ox_lib menu
    -- This integrates perfectly with the existing player inspection system
    TriggerEvent('QC-AdvancedMedic:client:ShowInspectionPanel', inspectionData)
end)

-- Mission inspection now uses the NUI system instead of ox_lib menus
-- This provides the same interface as player-to-player inspections for training consistency

-- Refresh NUI with updated mission wound data after treatments
RegisterNetEvent('QC-AdvancedMedic:client:RefreshMissionNUI', function()
    if not medicMissionActive or not medicMissionData then return end
    
    -- Send updated wound data to NUI
    local inspectionData = {
        playerId = -1,
        playerName = medicMissionData.patientData.playerName,
        playerSource = medicMissionData.patientData.source,
        wounds = medicMissionData.patientData.wounds,
        treatments = medicMissionData.patientData.treatments,
        infections = medicMissionData.patientData.infections,
        bandages = medicMissionData.patientData.bandages,
        healthData = medicMissionData.patientData.healthData,
        bloodLevel = medicMissionData.patientData.bloodLevel,
        isBleeding = medicMissionData.patientData.isBleeding,
        description = medicMissionData.patientData.description,
        vitals = {
            temperature = 98.6,
            bloodLevel = medicMissionData.patientData.bloodLevel,
            isDead = false
        }
    }
    
    -- Trigger NUI update
    SendNUIMessage({
        type = 'update-mission-wounds',
        data = inspectionData
    })
    
    if Config.Debug then
        print("^2[MISSION NUI] Refreshed wound data after treatment^7")
    end
end)

-- Handle medicine application to mission NPCs
RegisterNetEvent('QC-AdvancedMedic:client:ApplyMissionMedicine', function(medicineType)
    if not medicMissionActive or not medicMissionData then return end
    
    local medicineConfig = Config.MedicineTypes[medicineType]
    if not medicineConfig then return end
    
    -- Consume the medicine item from inventory
    TriggerServerEvent('QC-AdvancedMedic:server:removeitem', medicineConfig.itemName, 1)
    
    -- Mark only PAIN conditions as treated with medicine (not bleeding)
    local treatedParts = {}
    for bodyPart, woundData in pairs(medicMissionData.patientData.wounds or {}) do
        if woundData and woundData.painLevel and woundData.painLevel > 0 then
            -- Add medicine treatment to the wound (only affects pain, not bleeding)
            if not woundData.treatments then
                woundData.treatments = {}
            end
            
            woundData.treatments[medicineType .. "_pain"] = {
                treatmentType = "medicine",
                medicineType = medicineType,
                appliedTime = GetGameTimer(),
                appliedBy = GetPlayerServerId(PlayerId()),
                duration = medicineConfig.duration * 1000,
                effectiveness = medicineConfig.effectiveness or 80,
                painReliefLevel = medicineConfig.painReliefLevel or 3,
                status = "active",
                treatsCondition = "pain" -- Only treats pain, not bleeding
            }
            
            table.insert(treatedParts, bodyPart .. " (pain)")
        end
    end
    
    -- Show notifications
    if #treatedParts > 0 then
        lib.notify({
            title = 'Medicine Administered',
            description = string.format(locale('treatment_applied_medicine'), medicineConfig.label, #treatedParts),
            type = 'success',
            duration = 8000
        })
        
        if Config.Debug then
            print(string.format("^2[MISSION MEDICINE] Applied %s to mission NPC body parts: %s^7", 
                medicineType, table.concat(treatedParts, ", ")))
        end
        
        -- Check if this completes the mission treatment requirements
        checkMissionTreatmentProgress()
    else
        lib.notify({
            title = 'No Treatment Needed',
            description = locale('treatment_no_pain_conditions'),
            type = 'inform',
            duration = 5000
        })
    end
end)

-- Handle bandage application to mission NPCs
RegisterNetEvent('QC-AdvancedMedic:client:ApplyMissionBandage', function(bodyPart, bandageType)
    if not medicMissionActive or not medicMissionData then return end
    
    local bandageConfig = Config.BandageTypes[bandageType]
    if not bandageConfig then return end
    
    -- Consume the bandage item from inventory
    TriggerServerEvent('QC-AdvancedMedic:server:removeitem', bandageConfig.itemName, 1)
    
    -- Find the wound for this body part
    local woundData = medicMissionData.patientData.wounds[bodyPart]
    if not woundData then
        lib.notify({
            title = 'No Wound Found',
            description = string.format(locale('treatment_no_wound_bandage'), bodyPart),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Check if this is appropriate for bandage (bleeding 1-6)
    local bleedingLevel = woundData.bleedingLevel or 0
    if bleedingLevel < 1 or bleedingLevel > 6 then
        lib.notify({
            title = 'Inappropriate Treatment',
            description = string.format(locale('treatment_different_treatment'), bleedingLevel),
            type = 'warning',
            duration = 5000
        })
        return
    end
    
    -- Apply bandage treatment
    if not woundData.treatments then
        woundData.treatments = {}
    end
    
    woundData.treatments[bandageType .. "_bleeding"] = {
        treatmentType = "bandage",
        bandageType = bandageType,
        appliedTime = GetGameTimer(),
        appliedBy = GetPlayerServerId(PlayerId()),
        effectiveness = bandageConfig.effectiveness or 80,
        status = "active",
        treatsCondition = "bleeding" -- Treats bleeding, not pain
    }
    
    lib.notify({
        title = 'Bandage Applied',
        description = string.format(locale('treatment_bandage_applied'), bandageConfig.label or bandageType, bodyPart),
        type = 'success',
        duration = 8000
    })
    
    if Config.Debug then
        print(string.format("^2[MISSION BANDAGE] Applied %s to %s (bleeding level: %d)^7", bandageType, bodyPart, bleedingLevel))
    end
    
    checkMissionTreatmentProgress()
end)

-- Handle tourniquet application to mission NPCs
RegisterNetEvent('QC-AdvancedMedic:client:ApplyMissionTourniquet', function(bodyPart, tourniquetType)
    if not medicMissionActive or not medicMissionData then return end
    
    local tourniquetConfig = Config.TourniquetTypes[tourniquetType]
    if not tourniquetConfig then return end
    
    -- Consume the tourniquet item from inventory
    TriggerServerEvent('QC-AdvancedMedic:server:removeitem', tourniquetConfig.itemName, 1)
    
    -- Find the wound for this body part
    local woundData = medicMissionData.patientData.wounds[bodyPart]
    if not woundData then
        lib.notify({
            title = 'No Wound Found',
            description = string.format(locale('treatment_no_wound_tourniquet'), bodyPart),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Check if this is appropriate for tourniquet (bleeding 7+)
    local bleedingLevel = woundData.bleedingLevel or 0
    if bleedingLevel < 7 then
        lib.notify({
            title = 'Inappropriate Treatment',
            description = string.format(locale('treatment_use_bandage'), bleedingLevel),
            type = 'warning',
            duration = 5000
        })
        return
    end
    
    -- Apply tourniquet treatment
    if not woundData.treatments then
        woundData.treatments = {}
    end
    
    woundData.treatments[tourniquetType .. "_severe_bleeding"] = {
        treatmentType = "tourniquet",
        tourniquetType = tourniquetType,
        appliedTime = GetGameTimer(),
        appliedBy = GetPlayerServerId(PlayerId()),
        effectiveness = tourniquetConfig.effectiveness or 90,
        status = "active",
        treatsCondition = "severe_bleeding" -- Treats severe bleeding only
    }
    
    lib.notify({
        title = 'Tourniquet Applied',
        description = string.format(locale('treatment_tourniquet_applied'), tourniquetConfig.label or tourniquetType, bodyPart),
        type = 'success',
        duration = 8000
    })
    
    if Config.Debug then
        print(string.format("^2[MISSION TOURNIQUET] Applied %s to %s (bleeding level: %d)^7", tourniquetType, bodyPart, bleedingLevel))
    end
    
    checkMissionTreatmentProgress()
end)

-- Check mission treatment progress and completion
function checkMissionTreatmentProgress()
    if not medicMissionData or not medicMissionData.patientData then return end
    
    local totalConditions = 0
    local treatedConditions = 0
    local treatmentStatus = {}
    
    for bodyPart, woundData in pairs(medicMissionData.patientData.wounds or {}) do
        local painLevel = woundData.painLevel or 0
        local bleedingLevel = woundData.bleedingLevel or 0
        
        -- Count each condition type that needs treatment
        if painLevel > 0 then
            totalConditions = totalConditions + 1
            local painTreated = false
            
            -- Check if pain has been treated with medicine
            if woundData.treatments then
                for treatmentId, treatment in pairs(woundData.treatments) do
                    if treatment.status == "active" and treatment.treatsCondition == "pain" then
                        painTreated = true
                        break
                    end
                end
            end
            
            if painTreated then
                treatedConditions = treatedConditions + 1
                treatmentStatus[bodyPart .. "_pain"] = "✅ Pain treated with medicine"
            else
                treatmentStatus[bodyPart .. "_pain"] = "❌ Pain requires medicine"
            end
        end
        
        if bleedingLevel > 0 then
            totalConditions = totalConditions + 1
            local bleedingTreated = false
            
            -- Check if bleeding has been treated appropriately
            if woundData.treatments then
                for treatmentId, treatment in pairs(woundData.treatments) do
                    if treatment.status == "active" then
                        -- Severe bleeding (7+) needs tourniquet, light-moderate (1-6) needs bandage
                        if bleedingLevel >= 7 and treatment.treatsCondition == "severe_bleeding" then
                            bleedingTreated = true
                            break
                        elseif bleedingLevel >= 1 and bleedingLevel <= 6 and treatment.treatsCondition == "bleeding" then
                            bleedingTreated = true
                            break
                        end
                    end
                end
            end
            
            if bleedingTreated then
                treatedConditions = treatedConditions + 1
                if bleedingLevel >= 7 then
                    treatmentStatus[bodyPart .. "_bleeding"] = "✅ Severe bleeding treated with tourniquet"
                else
                    treatmentStatus[bodyPart .. "_bleeding"] = "✅ Bleeding treated with bandage"
                end
            else
                if bleedingLevel >= 7 then
                    treatmentStatus[bodyPart .. "_bleeding"] = "❌ Severe bleeding requires tourniquet"
                else
                    treatmentStatus[bodyPart .. "_bleeding"] = "❌ Bleeding requires bandage"
                end
            end
        end
    end
    
    if Config.Debug then
        print(string.format("^3[MISSION] Treatment progress: %d/%d conditions treated^7", treatedConditions, totalConditions))
        for condition, status in pairs(treatmentStatus) do
            print(string.format("^3[MISSION] %s: %s^7", condition, status))
        end
    end
    
    -- Complete mission when ALL conditions are treated appropriately
    if treatedConditions >= totalConditions and totalConditions > 0 then
        CreateThread(function()
            Wait(2000) -- Give player time to see the treatment applied
            
            lib.notify({
                title = 'Mission Complete!',
                description = string.format(locale('mission_all_treated'), totalConditions),
                type = 'success',
                duration = 10000
            })
            
            Wait(3000)
            completeMissionTreatment()
        end)
    else
        -- Show progress feedback
        lib.notify({
            title = 'Treatment Progress',
            description = string.format(locale('mission_progress'), treatedConditions, totalConditions),
            type = 'inform',
            duration = 5000
        })
    end
end

-- Treatment functionality is now handled through NUI callbacks
-- Mission completion will be checked through the existing treatment system

-- Treatment functions are now integrated with the NUI system
-- The existing treatment callbacks will handle mission NPCs automatically

-- Start patient transport for surgery missions (RedM follow system)
function startPatientTransport()
    if not medicMissionData or medicMissionData.missionType ~= 'surgery' then return end
    
    lib.notify({
        title = 'Transport Required',
        description = locale('mission_ready_transport'),
        type = 'inform',
        duration = 5000
    })
    
    -- Make patient follow the medic
    startPatientFollow()
    
    lib.notify({
        title = 'Patient Following',
        description = locale('mission_following'),
        type = 'success',
        duration = 7000
    })
    
    -- Set GPS to medical station
    local stationCoords = ConfigMissions.Settings.medicalStationCoords
    if Config.AddGPSRoute then
        ClearGpsMultiRoute()
        StartGpsMultiRoute(6, true, true)
        AddPointToGpsMultiRoute(stationCoords.x, stationCoords.y, stationCoords.z)
        SetGpsMultiRouteRender(true)
    end
    
    -- Start monitoring for horse mounting
    CreateThread(function()
        while medicMissionPed and DoesEntityExist(medicMissionPed) and not missionPatientTransported do
            local playerPed = cache.ped
            local playerMount = GetMount(playerPed)
            
            -- Check if player mounted a horse and patient isn't already mounted
            if playerMount and playerMount ~= 0 and not IS_PED_ON_MOUNT(medicMissionPed) then
                mountPatientOnHorse(playerMount)
            end
            
            -- Check if player dismounted and patient is mounted
            if (not playerMount or playerMount == 0) and IS_PED_ON_MOUNT(medicMissionPed) then
                dismountPatientFromHorse()
            end
            
            -- Check if at medical station
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - stationCoords)
            if distance < ConfigMissions.Settings.transportRange then
                handlePatientArrival()
                break
            end
            
            Wait(1000)
        end
    end)
end

-- Start patient following the medic
function startPatientFollow()
    if not medicMissionPed or not DoesEntityExist(medicMissionPed) then return end
    
    -- Clear any existing tasks
    ClearPedTasks(medicMissionPed)
    
    -- Make patient follow the medic with appropriate offset
    TaskFollowToOffsetOfEntity(medicMissionPed, cache.ped, -2.0, -2.0, 0.0, 1.0, -1, 2.5, true, true, false, true, true, true)
    
    -- Set relationship to companion so they follow properly
    SetPedRelationshipGroupHash(medicMissionPed, GetHashKey('COMPANION'))
    
    lib.notify({
        title = 'Patient Stabilized',
        description = locale('mission_following_station'),
        type = 'success',
        duration = 5000
    })
end

-- Mount patient on horse when player mounts
function mountPatientOnHorse(playerMount)
    if not medicMissionPed or not DoesEntityExist(medicMissionPed) or not playerMount then return end
    
    -- Check if horse has available seat (behind player)
    local availableSeats = GetVehicleMaxNumberOfPassengers(playerMount)
    if availableSeats > 0 then
        -- Clear patient tasks
        ClearPedTasks(medicMissionPed)
        
        -- Mount patient on horse behind player
        TaskMountAnimal(medicMissionPed, playerMount, -1, -1, 1.0, 1)
        
        lib.notify({
            title = 'Patient Mounted',
            description = locale('mission_mounted_horse'),
            type = 'inform',
            duration = 3000
        })
    end
end

-- Dismount patient from horse when player dismounts
function dismountPatientFromHorse()
    if not medicMissionPed or not DoesEntityExist(medicMissionPed) then return end
    
    -- Dismount patient
    TaskDismountAnimal(medicMissionPed, 1, 0, 0, 0, 0)
    
    -- Wait a moment then resume following
    CreateThread(function()
        Wait(2000)
        if medicMissionPed and DoesEntityExist(medicMissionPed) and not missionPatientTransported then
            startPatientFollow()
        end
    end)
    
    lib.notify({
        title = 'Patient Dismounted',
        description = locale('mission_dismounted'),
        type = 'inform',
        duration = 3000
    })
end

-- Handle patient arrival at medical station
function handlePatientArrival()
    if not medicMissionPed or missionPatientTransported then return end
    
    missionPatientTransported = true
    
    -- Clear patient tasks
    ClearPedTasks(medicMissionPed)
    
    lib.notify({
        title = 'Arrived at Medical Station',
        description = locale('mission_delivered'),
        type = 'success',
        duration = 5000
    })
    
    -- Don't auto-complete - let the player access surgery menu through inspection
    lib.notify({
        title = 'Surgery Available',
        description = locale('mission_inspect_patient'),
        type = 'inform',
        duration = 7000
    })
end

-- Load patient into ambulance (legacy function - kept for compatibility)
function loadPatientIntoAmbulance()
    if not medicMissionPed or not transportVehicle then return end
    
    local playerCoords = GetEntityCoords(cache.ped)
    local pedCoords = GetEntityCoords(medicMissionPed)
    local distance = #(playerCoords - pedCoords)
    
    if distance > ConfigMissions.Settings.transportRange then
        lib.notify({
            title = 'Too Far',
            description = locale('mission_closer_patient'),
            type = 'error',
            duration = 3000
        })
        return
    end
    
    -- Animation for loading patient
    TaskStartScenarioInPlace(cache.ped, `WORLD_HUMAN_CROUCH_INSPECT`, -1, true, false, false, false)
    
    if lib.progressBar({
        duration = 8000,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disableControl = true,
        disable = { move = true, mouse = true },
        label = 'Loading patient into ambulance...',
        anim = {
            dict = 'mini_games@story@mob4@heal_jules@bandage@arthur',
            clip = 'bandage_fast',
            flag = 1,
        },
    }) then
        ClearPedTasks(cache.ped)
        
        -- "Load" patient (make them invisible and attach to vehicle)
        SetEntityVisible(medicMissionPed, false)
        FreezeEntityPosition(medicMissionPed, true)
        
        lib.notify({
            title = 'Patient Loaded',
            description = locale('mission_loaded_vehicle'),
            type = 'success',
            duration = 5000
        })
        
        -- Set GPS to medical station
        local stationCoords = ConfigMissions.Settings.medicalStationCoords
        if Config.AddGPSRoute then
            ClearGpsMultiRoute()
            StartGpsMultiRoute(6, true, true)
            AddPointToGpsMultiRoute(stationCoords.x, stationCoords.y, stationCoords.z)
            SetGpsMultiRouteRender(true)
        end
        
        -- Add target to unload at medical station
        CreateThread(function()
            while transportVehicle and DoesEntityExist(transportVehicle) and not missionPatientTransported do
                local vehCoords = GetEntityCoords(transportVehicle)
                local distanceToStation = #(vehCoords - stationCoords)
                
                if distanceToStation < ConfigMissions.Settings.transportRange then
                    exports.ox_target:addLocalEntity(transportVehicle, {
                        {
                            name = 'unload_patient',
                            icon = 'fa-solid fa-user-minus',
                            label = 'Unload Patient at Medical Station',
                            canInteract = function(entity, distance, coords, name)
                                return distance < ConfigMissions.Settings.transportRange
                            end,
                            onSelect = function()
                                unloadPatientAtStation()
                            end
                        }
                    })
                    break
                end
                Wait(1000)
            end
        end)
        
    else
        ClearPedTasks(cache.ped)
        lib.notify({
            title = 'Cancelled',
            description = locale('mission_loading_cancelled'),
            type = 'error',
            duration = 3000
        })
    end
end

-- Unload patient at medical station
function unloadPatientAtStation()
    if not transportVehicle or missionPatientTransported then return end
    
    local stationCoords = ConfigMissions.Settings.medicalStationCoords
    local vehCoords = GetEntityCoords(transportVehicle)
    local distance = #(vehCoords - stationCoords)
    
    if distance > ConfigMissions.Settings.transportRange then
        lib.notify({
            title = 'Wrong Location',
            description = locale('mission_at_station'),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Animation for unloading
    TaskStartScenarioInPlace(cache.ped, `WORLD_HUMAN_CROUCH_INSPECT`, -1, true, false, false, false)
    
    if lib.progressBar({
        duration = 6000,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disableControl = true,
        disable = { move = true, mouse = true },
        label = 'Unloading patient at medical station...'
    }) then
        ClearPedTasks(cache.ped)
        
        -- Move patient to surgery room
        local surgeryCoords = ConfigMissions.Settings.surgeryRoomCoords
        SetEntityCoords(medicMissionPed, surgeryCoords.x, surgeryCoords.y, surgeryCoords.z)
        SetEntityVisible(medicMissionPed, true)
        FreezeEntityPosition(medicMissionPed, true)
        
        -- Clean up transport vehicle
        DeleteEntity(transportVehicle)
        transportVehicle = nil
        
        missionPatientTransported = true
        
        lib.notify({
            title = 'Patient at Medical Station',
            description = locale('mission_moved_surgery'),
            type = 'success',
            duration = 7000
        })
        
        if Config.AddGPSRoute then
            ClearGpsMultiRoute()
        end
        
        -- Update mission blip to surgery room
        if medicMissionBlip then
            RemoveBlip(medicMissionBlip)
        end
        medicMissionBlip = BlipAddForCoords(1664425300, surgeryCoords.x, surgeryCoords.y, surgeryCoords.z)
        SetBlipSprite(medicMissionBlip, GetHashKey('blip_shop_doctor'), true)
        SetBlipScale(medicMissionBlip, 0.3)
        SetBlipName(medicMissionBlip, 'Surgery Patient')
        
    else
        ClearPedTasks(cache.ped)
        lib.notify({
            title = 'Cancelled',
            description = locale('mission_unload_cancelled'),
            type = 'error',
            duration = 3000
        })
    end
end

-- Start surgical procedures
function startSurgicalProcedures()
    if not medicMissionData or not missionPatientTransported then return end
    
    local surgeryTreatment = medicMissionData.medicalCondition.surgeryTreatment
    if not surgeryTreatment or not surgeryTreatment.surgicalProcedures then return end
    
    surgeryInProgress = true
    
    -- Show surgery menu
    showSurgeryMenu(surgeryTreatment.surgicalProcedures)
end

-- Show surgery procedure menu
function showSurgeryMenu(procedures)
    local options = {}
    
    table.insert(options, {
        title = '⚕️ Surgical Procedures Required',
        description = locale('mission_select_procedures'),
        disabled = true
    })
    
    for i, procedure in ipairs(procedures) do
        local completed = missionStepData['surgery_' .. i] and missionStepData['surgery_' .. i].completed
        local statusIcon = completed and '✅' or '🔄'
        
        table.insert(options, {
            title = statusIcon .. ' ' .. (ConfigMissions.SurgeryProcedures[procedure.procedure] and ConfigMissions.SurgeryProcedures[procedure.procedure].name or procedure.procedure),
            description = procedure.description .. (completed and ' (COMPLETED)' or ''),
            disabled = completed,
            onSelect = function()
                if not completed then
                    performSurgicalProcedure(procedure, i)
                end
            end
        })
    end
    
    -- Check if all procedures are complete
    local allComplete = true
    for i, _ in ipairs(procedures) do
        if not (missionStepData['surgery_' .. i] and missionStepData['surgery_' .. i].completed) then
            allComplete = false
            break
        end
    end
    
    if allComplete then
        table.insert(options, {
            title = '🎯 Complete Surgery',
            description = locale('mission_procedures_complete'),
            onSelect = function()
                completeSurgicalMission()
            end
        })
    end
    
    table.insert(options, {
        title = 'Close',
        description = locale('mission_close_surgery'),
        onSelect = function()
        end
    })
    
    lib.registerContext({
        id = 'surgery_procedures',
        title = '🏥 Surgical Procedures - ' .. medicMissionData.medicalCondition.name,
        options = options
    })
    
    lib.showContext('surgery_procedures')
end

-- Perform a specific surgical procedure
function performSurgicalProcedure(procedure, procedureIndex)
    local procedureData = ConfigMissions.SurgeryProcedures[procedure.procedure]
    if not procedureData then return end
    
    -- Check if player has required items
    for _, item in ipairs(procedureData.requiredItems) do
        if not RSGCore.Functions.HasItem(item, 1) then
            lib.notify({
                title = 'Missing Equipment',
                description = string.format(locale('mission_need_item'), item),
                type = 'error',
                duration = 5000
            })
            return
        end
    end
    
    -- Start procedure animation and progress
    TaskStartScenarioInPlace(cache.ped, `WORLD_HUMAN_CROUCH_INSPECT`, -1, true, false, false, false)
    
    if lib.progressBar({
        duration = procedureData.duration * 1000,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disableControl = true,
        disable = { move = true, mouse = true },
        label = 'Performing ' .. procedureData.name .. '...',
        anim = {
            dict = 'mini_games@story@mob4@heal_jules@bandage@arthur',
            clip = 'bandage_fast',
            flag = 1,
        },
    }) then
        ClearPedTasks(cache.ped)
        
        -- Consume required items
        for _, item in ipairs(procedureData.requiredItems) do
            if ConfigMissions.MedicalEquipment[item] and ConfigMissions.MedicalEquipment[item].consumable then
                TriggerServerEvent('QC-AdvancedMedic:server:removeitem', item, 1)
            end
        end
        
        -- Mark procedure as completed
        missionStepData['surgery_' .. procedureIndex] = {
            completed = true,
            completedAt = GetGameTimer()
        }
        
        lib.notify({
            title = 'Procedure Complete',
            description = procedureData.name .. ' completed successfully.',
            type = 'success',
            duration = 5000
        })
        
        -- Show updated surgery menu
        local surgeryTreatment = medicMissionData.medicalCondition.surgeryTreatment
        showSurgeryMenu(surgeryTreatment.surgicalProcedures)
        
    else
        ClearPedTasks(cache.ped)
        lib.notify({
            title = 'Procedure Cancelled',
            description = locale('mission_procedure_cancelled'),
            type = 'error',
            duration = 3000
        })
    end
end

-- Complete surgical mission
function completeSurgicalMission()
    surgeryInProgress = false
    
    lib.notify({
        title = 'Surgery Successful!',
        description = locale('mission_patient_stable'),
        type = 'success',
        duration = 10000
    })
    
    completeMissionTreatment()
end

-- Get closest vehicle spawn point
function GetClosestVehicleSpawn(coords)
    local spawns = ConfigMissions.PatientTransport.ambulanceSpawns
    local closestSpawn = spawns[1]
    local closestDistance = #(coords - vector3(spawns[1].x, spawns[1].y, spawns[1].z))
    
    for i = 2, #spawns do
        local distance = #(coords - vector3(spawns[i].x, spawns[i].y, spawns[i].z))
        if distance < closestDistance then
            closestDistance = distance
            closestSpawn = spawns[i]
        end
    end
    
    return closestSpawn
end

-- Complete the mission treatment
function completeMissionTreatment()
    -- "Revive" NPC: Stop Animation and let him go
    if medicMissionPed and DoesEntityExist(medicMissionPed) then
        ClearPedTasksImmediately(medicMissionPed)
        FreezeEntityPosition(medicMissionPed, false)
        SetPedFleeAttributes(medicMissionPed, 0, 0)
        SetPedCombatAttributes(medicMissionPed, 17, 0)
        SetPedSeeingRange(medicMissionPed, 25.0)
        SetPedHearingRange(medicMissionPed, 25.0)
        SetPedKeepTask(medicMissionPed, false)
        
        -- Let him walk random like a plain ped
        TaskWanderStandard(medicMissionPed, 10.0, 10)
        
        -- NPC disappears after 10 seconds
        CreateThread(function()
            Wait(10000)
            if DoesEntityExist(medicMissionPed) then
                DeleteEntity(medicMissionPed)
            end
        end)
    end
    
    -- Clean up mission data
    if medicMissionBlip then
        RemoveBlip(medicMissionBlip)
        medicMissionBlip = nil
    end
    
    if transportVehicle and DoesEntityExist(transportVehicle) then
        DeleteEntity(transportVehicle)
        transportVehicle = nil
    end
    
    if Config.AddGPSRoute then
        ClearGpsMultiRoute()
    end
    
    -- Determine reward based on mission type
    local missionType = medicMissionData and medicMissionData.missionType or 'field'
    TriggerServerEvent('QC-AdvancedMedic:server:MissionReward', missionType)
    
    -- Reset mission variables
    medicMissionActive = false
    medicMissionPed = nil
    medicMissionData = nil
    missionPatientTransported = false
    surgeryInProgress = false
    currentMissionStep = 0
    missionStepData = {}
end

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
