--=========================================================
-- QC-ADVANCED MEDIC - ENVIRONMENTAL & ANIMAL ATTACK SYSTEM
--=========================================================
-- This file handles environmental damage and animal attacks
-- Integrates with the existing wound system for realistic injury mechanics
-- Features: Fall damage, horse accidents, animal attacks, fractures, bone breaks
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- Environmental tracking variables
local LastVehicleSpeed = 0
local LastMountSpeed = 0
local PlayerWasOnMount = false
local PlayerWasInVehicle = false
local LastEnvironmentalCheck = 0
local ENVIRONMENTAL_CHECK_INTERVAL = 1000 -- Check every 1 second

-- Animal attack tracking (handled by main wound system now)
local NearbyAnimals = {}


--=========================================================
-- FRACTURE TRACKING VARIABLES
--=========================================================
local PlayerFractures = {} -- Client-side fracture storage

--=========================================================
-- FRACTURE LOADING EVENTS
--=========================================================

-- Load fractures from server on login/spawn
RegisterNetEvent('QC-AdvancedMedic:client:LoadFractures')
AddEventHandler('QC-AdvancedMedic:client:LoadFractures', function(fractures)
    PlayerFractures = fractures or {}
    
    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        local count = 0
        local fractureList = {}
        for bodyPart, fracture in pairs(PlayerFractures) do
            count = count + 1
            table.insert(fractureList, string.format("^4%s(T:%s,S:^3%d^4)", 
                bodyPart, fracture.type, fracture.severity))
        end
        print(string.format("^3[^4FRACTURES^3] Loaded ^3%d^3 fractures from database^7", count))
        if count > 0 then
            print(string.format("^3[^4FRACTURE LOAD^3] ^4%s^7", table.concat(fractureList, "^7, ^4")))
        end
    end
end)

-- Handle fracture healed event
RegisterNetEvent('QC-AdvancedMedic:client:FractureHealed')
AddEventHandler('QC-AdvancedMedic:client:FractureHealed', function(bodyPart)
    if PlayerFractures[bodyPart] then
        PlayerFractures[bodyPart] = nil
        
        lib.notify({
            title = "Fracture Healed",
            description = string.format("Your %s fracture has fully healed!", 
                Config.BodyParts[bodyPart] and Config.BodyParts[bodyPart].label:lower() or bodyPart:lower()),
            type = 'success',
            duration = 8000
        })
        
        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
            print(string.format("^2[FRACTURES] Healed fracture: %s^7", bodyPart))
        end
    end
end)

-- Request fracture loading on spawn
CreateThread(function()
    while LocalPlayer.state.isLoggedIn == nil do
        Wait(100)
    end
    
    if LocalPlayer.state.isLoggedIn then
        Wait(2000) -- Wait for other systems to initialize
        TriggerServerEvent('QC-AdvancedMedic:server:LoadFractures')
    end
end)

--=========================================================
-- ENVIRONMENTAL DAMAGE HANDLER (Called by wound system)
--=========================================================
function HandleEnvironmentalDamage(damageType, bodyPart, isRagdoll)
    if damageType == "fall" then
        local ped = PlayerPedId()
        local height = GetEntityHeightAboveGround(ped)
        local velocity = GetEntityVelocity(ped)
        local speed = math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2)
        isRagdoll = isRagdoll or false -- Default to false if not provided
        
        -- For ragdoll falls, use Y-axis velocity as fall severity indicator
        local fallSeverity = height
        if isRagdoll then
            -- Use downward velocity (Y-axis) as primary severity indicator
            local downwardSpeed = math.abs(velocity.z) -- Z is vertical axis in GTA/RedM
            local yAxisSeverity = downwardSpeed * 1.2 -- Convert velocity to distance equivalent
            fallSeverity = math.max(height, yAxisSeverity)
        end
        
        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
            print(string.format("^3[ENV DAMAGE] Fall detected: Height=%.1f, Speed=%.1f, Severity=%.1f, BodyPart=%s, Ragdoll=%s^7", 
                height, speed, fallSeverity, bodyPart, tostring(isRagdoll)))
        end
        
        -- Only enhance if significant fall severity
        if fallSeverity >= Config.FallDamage.minHeight then
            local injuryType = "bruise"
            local shouldEnhance = false
            
            -- Simple distance-based logic
            if isRagdoll then
                -- Ragdoll falls: more dangerous, lower thresholds
                if fallSeverity >= Config.FallDamage.ragdollBreakHeight then
                    injuryType = "bone_break"
                    shouldEnhance = true
                elseif fallSeverity >= Config.FallDamage.ragdollFractureHeight then
                    injuryType = "fracture"
                    shouldEnhance = true
                end
            else
                -- Non-ragdoll falls: controlled landing, higher thresholds
                if fallSeverity >= Config.FallDamage.breakHeight then
                    injuryType = "bone_break"
                    shouldEnhance = true
                elseif fallSeverity >= Config.FallDamage.fractureHeight then
                    injuryType = "fracture"
                    shouldEnhance = true
                end
            end
            
            -- Apply enhanced injury if threshold met
            if shouldEnhance then
                -- Calculate severity on 1-10 scale based on fall severity and ragdoll status
                local severity = 5 -- Default moderate fracture
                
                if injuryType == "bone_break" then
                    -- Bone breaks: severity 7-10
                    if fallSeverity >= 25 then
                        severity = 10 -- Critical bone break
                    elseif fallSeverity >= 20 then
                        severity = 9  -- Severe bone break
                    elseif fallSeverity >= 15 then
                        severity = 8  -- Major bone break
                    else
                        severity = 7  -- Moderate bone break
                    end
                else
                    -- Fractures: severity 1-6
                    if fallSeverity >= 12 then
                        severity = 6  -- Severe fracture
                    elseif fallSeverity >= 8 then
                        severity = 5  -- Moderate fracture
                    elseif fallSeverity >= 5 then
                        severity = 4  -- Minor-moderate fracture
                    else
                        severity = 3  -- Minor fracture
                    end
                end
                
                local additionalPain = severity + math.random(-1, 2)
                local minimalBleeding = injuryType == "bone_break" and 2 or 1
                
                -- Create fracture entry in separate fractures database
                local fractureData = {
                    type = injuryType, -- "fracture" or "bone_break"
                    severity = severity,
                    painLevel = additionalPain,
                    mobilityImpact = injuryType == "bone_break" and (0.6 + (severity - 7) * 0.1) or (0.2 + (severity - 1) * 0.05), -- Scaled mobility impact based on severity
                    healingProgress = 0.0,
                    requiresSurgery = severity >= 8, -- Surgery needed for severe injuries (8+)
                    description = injuryType == "bone_break" and 
                        string.format("Severe bone break in %s from high-impact fall. Complete structural failure requiring immediate medical intervention.", Config.BodyParts[bodyPart] and Config.BodyParts[bodyPart].label or bodyPart) or
                        string.format("Bone fracture in %s from fall impact. Painful crack in bone structure limiting mobility and function.", Config.BodyParts[bodyPart] and Config.BodyParts[bodyPart].label or bodyPart)
                }
                
                -- Save fracture to database
                TriggerServerEvent('QC-AdvancedMedic:server:SaveFracture', bodyPart, fractureData)
                
                -- Store in client-side fracture tracking
                if not PlayerFractures then PlayerFractures = {} end
                PlayerFractures[bodyPart] = fractureData
                
                -- Severe injury notification
                lib.notify({
                    title = injuryType == "bone_break" and "Bone Break!" or "Fracture!",
                    description = string.format("The fall may have %s your %s! Seek immediate medical attention.", 
                        injuryType == "bone_break" and "broken" or "fractured",
                        Config.BodyParts[bodyPart] and Config.BodyParts[bodyPart].label:lower() or bodyPart:lower()
                    ),
                    type = 'error',
                    duration = 12000
                })
                
                -- Extended ragdoll for severe injuries
                SetPedToRagdoll(ped, 4000, 7000, 0, true, true, false)
                
                if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                    print(string.format("^1[ENHANCED FALL] %s %s: Severity=%.1f^7", 
                        bodyPart, injuryType, fallSeverity))
                end
            end
        end
        
    end
end

--=========================================================
-- MOUNT/HORSE ACCIDENT SYSTEM
--=========================================================
function HandleMountAccident(accidentType, bodyPart, speed)
    -- This gets called by the wound system when mount damage is detected
    -- The bone/bodyPart is already determined by the main wound system
    
    -- Simple severity calculation
    local severity = math.min(math.floor((speed or 10) * 1.5 / 10), 8)
    
    -- Notification and effects
    local accidentDesc = accidentType == "trampled" and "trampled by your horse" or "thrown from your horse"
    lib.notify({
        title = "Horse Accident",
        description = string.format("You were %s! Check for injuries.", accidentDesc),
        type = 'error',
        duration = 8000
    })
    
    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        print(string.format("^1[MOUNT ACCIDENT] %s - %s: Speed=%.1f^7", 
            accidentType, bodyPart, speed or 0))
    end
    
    -- Extended ragdoll for mount accidents
    SetPedToRagdoll(PlayerPedId(), 3000, 6000, 0, true, true, false)
end

--=========================================================
-- ANIMAL INFECTION RISK HANDLER
--=========================================================
-- This function is called by the main wound system when an animal attack is detected
function HandleAnimalAttackInfection(animalModel, bodyPart)
    -- Simple infection risk based on animal type (no complex config needed)
    local animalNames = {
        ['a_c_wolf'] = "Wolf",
        ['a_c_cougar'] = "Cougar", 
        ['a_c_bear_01'] = "Bear",
        ['a_c_deer_01'] = "Buck",
        ['a_c_snake_01'] = "Snake",
        ['a_c_coyote_01'] = "Coyote",
        ['a_c_fox_01'] = "Fox"
    }
    
    local animalName = animalNames[animalModel] or "Animal"
    local isVenomous = animalModel == GetHashKey("a_c_snake_01")
    
    -- Basic infection risk: predators higher, herbivores lower
    local infectionRisk = 0.15 -- Default 15%
    if animalModel == GetHashKey("a_c_snake_01") then
        infectionRisk = 0.8 -- Snakes 80% (venom)
    elseif animalModel == GetHashKey("a_c_wolf") or animalModel == GetHashKey("a_c_cougar") or animalModel == GetHashKey("a_c_bear_01") then
        infectionRisk = 0.25 -- Predators 25%
    end
    
    -- Roll for infection
    if math.random() <= infectionRisk then
        CreateThread(function()
            Wait(5000) -- 5 second delay before infection can start
            if CreateInfection then
                CreateInfection(bodyPart)
            end
            
            if isVenomous then
                lib.notify({
                    title = "Venomous Bite",
                    description = "The snake bite may be venomous! Seek treatment immediately.",
                    type = 'error',
                    duration = 12000
                })
            end
        end)
    end
    
    -- Attack notification
    lib.notify({
        title = "Animal Attack",
        description = string.format("You were attacked by a %s! Check for injuries.", animalName),
        type = 'error',
        duration = 8000
    })
end

--=========================================================
-- ANIMAL DETECTION SYSTEM
--=========================================================
local function DetectNearbyAnimals()
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    NearbyAnimals = {}
    
    -- Find all nearby peds (animals)
    local handle, animal = FindFirstPed()
    local success
    
    repeat
        if DoesEntityExist(animal) and animal ~= ped and not IsPedAPlayer(animal) then
            local distance = #(playerCoords - GetEntityCoords(animal))
            if distance <= 5.0 then -- Only check very close animals
                local model = GetEntityModel(animal)
                
                -- Check if this is a known dangerous animal
                local dangerousAnimals = {
                    [-1392359921] = "Wolf",
                    [GetHashKey("a_c_wolf")] = "Wolf",
                    [GetHashKey("a_c_cougar")] = "Cougar",
                    [GetHashKey("a_c_bear_01")] = "Bear",
                    [GetHashKey("a_c_snake_01")] = "Snake",
                    [GetHashKey("a_c_coyote_01")] = "Coyote"
                }
                
                if dangerousAnimals[model] then
                    table.insert(NearbyAnimals, {
                        entity = animal,
                        model = model,
                        distance = distance,
                        name = dangerousAnimals[model]
                    })
                end
            end
        end
        success, animal = FindNextPed(handle)
    until not success
    EndFindPed(handle)
end

--=========================================================
-- SPEED AND ACCIDENT MONITORING
--=========================================================
local function MonitorPlayerMovement()
    local ped = PlayerPedId()
    local currentTime = GetGameTimer()
    
    -- Only check every interval to avoid performance issues
    if currentTime - LastEnvironmentalCheck < ENVIRONMENTAL_CHECK_INTERVAL then return end
    LastEnvironmentalCheck = currentTime
    
    -- Check if player is on a mount
    local mount = GetMount(ped)
    local isOnMount = mount and DoesEntityExist(mount)
    
    if isOnMount then
        local mountSpeed = GetEntitySpeed(mount) * 2.237 -- Convert to MPH
        
        -- Check for sudden mount accidents (sudden stop from high speed)
        if PlayerWasOnMount and LastMountSpeed > 8.0 then -- 8 MPH minimum speed
            local speedDelta = LastMountSpeed - mountSpeed
            
            if speedDelta > 15.0 then -- Sudden deceleration
                -- Chance for accident based on speed
                local accidentChance = (speedDelta / 30.0) * 0.3 -- 30% throw chance
                
                if math.random() <= accidentChance then
                    local accidentType = math.random() <= 0.15 and "trampled" or "thrown" -- 15% trample risk
                    HandleMountAccident(accidentType, "LOWER_BODY", LastMountSpeed) -- Default to lower body
                end
            end
        end
        
        LastMountSpeed = mountSpeed
        PlayerWasOnMount = true
    else
        PlayerWasOnMount = false
        LastMountSpeed = 0
    end
    
    -- Similar monitoring for vehicles could be added here
    -- Check if player is in a vehicle
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle and vehicle ~= 0 then
        -- Vehicle monitoring logic would go here
        PlayerWasInVehicle = true
    else
        PlayerWasInVehicle = false
    end
end

--=========================================================
-- GLOBAL FUNCTIONS FOR WOUND SYSTEM INTEGRATION  
--=========================================================
-- Functions are already global when defined without 'local'

--=========================================================
-- LEG INJURY RAGDOLL MECHANIC
--=========================================================
local function CheckLegInjuryRagdoll()
    local ped = PlayerPedId()
    
    -- Only check if player is moving
    if GetEntitySpeed(ped) > 1.0 and not IsPedRagdoll(ped) then
        -- Check for leg/foot/lower body fractures or breaks
        local hasLegInjury = false
        local fractureSeverity = 0
        
        -- Check PlayerFractures table for leg injuries
        if PlayerFractures then
            for bodyPart, fracture in pairs(PlayerFractures) do
                if (bodyPart == "RLEG" or bodyPart == "LLEG" or bodyPart == "LOWER_BODY") then
                    hasLegInjury = true
                    -- Use mobility impact to determine ragdoll chance
                    fractureSeverity = math.max(fractureSeverity, fracture.mobilityImpact or 0.4)
                    break
                end
            end
        end
        
        -- Also check traditional wounds for fracture descriptions (backward compatibility)
        if not hasLegInjury and PlayerWounds then
            for bodyPart, wound in pairs(PlayerWounds) do
                if (bodyPart == "RLEG" or bodyPart == "LLEG" or bodyPart == "LOWER_BODY") then
                    -- Check if wound description contains fracture or break
                    if wound.metadata and wound.metadata.description then
                        local desc = wound.metadata.description:lower()
                        if string.find(desc, "fracture") or string.find(desc, "break") or string.find(desc, "broken") then
                            hasLegInjury = true
                            fractureSeverity = 0.4 -- Default severity for wound-based fractures
                            break
                        end
                    end
                end
            end
        end
        
        -- Roll for ragdoll if leg injury present (higher chance with more severe fractures)
        if hasLegInjury then
            local baseChance = Config.FallDamage.ragdollChance or 5
            local adjustedChance = math.floor(baseChance + (fractureSeverity * 20)) -- Add up to 20% for severe fractures
            
            if math.random(1, 100) <= adjustedChance then
                SetPedToRagdoll(ped, 2000, 4000, 0, true, true, false)
                
                if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                    print(string.format("^1[LEG INJURY] Player ragdolled due to leg fracture/break while moving (chance: %d%%, severity: %.1f)^7", 
                        adjustedChance, fractureSeverity))
                end
            end
        end
    end
end

--=========================================================
-- MAIN ENVIRONMENTAL MONITORING THREAD
--=========================================================
CreateThread(function()
    while true do
        Wait(1000) -- Check every second for environmental hazards
        
        if LocalPlayer.state.isLoggedIn then
            MonitorPlayerMovement()
            DetectNearbyAnimals()
            CheckLegInjuryRagdoll() -- Check for leg injury ragdoll
        end
    end
end)


--=========================================================
-- ANIMAL WEAPON DETECTION FUNCTION (Simplified)
--=========================================================
function GetAnimalWeaponHash(animalModel)
    -- Simple animal to weapon mapping (matches the hardcoded mapping in wound_system.lua)
    local animalWeapons = {
        [-1392359921] = GetHashKey("WEAPON_WOLF"), -- Verified wolf model hash
        [GetHashKey("a_c_wolf")] = GetHashKey("WEAPON_WOLF"),
        [GetHashKey("a_c_cougar")] = GetHashKey("WEAPON_COUGAR"),
        [GetHashKey("a_c_bear_01")] = GetHashKey("WEAPON_BEAR"),
        [GetHashKey("a_c_snake_01")] = GetHashKey("WEAPON_SNAKE"),
        [GetHashKey("a_c_coyote_01")] = GetHashKey("WEAPON_COYOTE"),
        [GetHashKey("a_c_deer_01")] = GetHashKey("WEAPON_DEER"),
        [GetHashKey("a_c_fox_01")] = GetHashKey("WEAPON_FOX"),
    }
    
    local weaponHash = animalWeapons[animalModel]
    if weaponHash then
        return weaponHash
    end
    
    -- Debug unknown animals
    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        print(string.format("^3[UNKNOWN ANIMAL] Model: %s (0x%X) - using fallback weapon^7", tostring(animalModel), animalModel))
    end
    
    -- Fallback to generic animal weapon if model not specifically defined
    return GetHashKey("WEAPON_ANIMAL")
end

--=========================================================
-- EXPORTS FOR EXTERNAL ACCESS
--=========================================================
exports('GetAnimalWeaponHash', GetAnimalWeaponHash)

exports('TriggerMountAccident', function(accidentType, severity)
    -- Manual trigger for mount accidents
    accidentType = accidentType or "thrown"
    severity = severity or LastMountSpeed
    HandleMountAccident(accidentType, "LOWER_BODY", severity)
end)

exports('GetNearbyDangerousAnimals', function()
    return NearbyAnimals
end)

if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
    print("^2[ENV SYSTEM] Environmental & Animal Attack System Loaded^7")
end