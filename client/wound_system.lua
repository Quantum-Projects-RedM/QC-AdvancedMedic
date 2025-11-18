--=========================================================
-- QC-ADVANCED MEDIC - WOUND SYSTEM
--=========================================================
-- This file handles the core wound detection, tracking, and progression
-- Uses the sophisticated Config.WeaponDamage and Config.InjuryStates systems
--=========================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

-- Core wound tracking variables
PlayerWounds = {}
local PlayerHealth = nil
local BleedingLevel = 0
local InfectionData = {}

-- Damage event tracking
local LastDamageWeapon = nil
local LastDamageTime = 0

-- Calculate body part health based on damage and store in wound
local function CalculateBodyPartHealth(bodyPart, painLevel, bleedingLevel)
    local bodyPartConfig = Config.BodyParts[bodyPart]
    if not bodyPartConfig then return 100.0, 100.0, 100.0 end
    
    local maxHealth = bodyPartConfig.maxHealth
    local totalDamage = (painLevel or 0) + (bleedingLevel or 0)
    
    -- Scale damage: 30% health loss per 10 damage points (max 60% loss)
    local scalingFactor = 0.3
    local healthLoss = (totalDamage * scalingFactor * maxHealth) / 10
    local currentHealth = math.max(0, maxHealth - healthLoss)
    local healthPercentage = (currentHealth / maxHealth) * 100
    
    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        print(string.format("^2[HEALTH] %s: %.1f%% (Pain:%.1f Bleed:%.1f)^7", 
            bodyPart, healthPercentage, painLevel or 0, bleedingLevel or 0))
    end
    
    return currentHealth, maxHealth, healthPercentage
end

-- Get body part health from wounds (optimized - no recalculation)
function GetBodyPartHealthData()
    local healthData = {}
    
    -- Default all body parts to 100% health
    for bodyPart, config in pairs(Config.BodyParts) do
        healthData[bodyPart] = {
            current = config.maxHealth,
            max = config.maxHealth,
            percentage = 100.0
        }
    end
    
    -- Update with wound data if it exists
    for bodyPart, wound in pairs(PlayerWounds) do
        if not wound.isScar and wound.currentHealth then
            healthData[bodyPart] = {
                current = wound.currentHealth,
                max = wound.maxHealth or Config.BodyParts[bodyPart].maxHealth,
                percentage = wound.healthPercentage or 100.0
            }
        end
    end
    
    return healthData
end


-- Efficient damage detection without heavy ped caching
local LastDamageTime = 0
local DAMAGE_COOLDOWN = 500 -- Minimum time between damage checks (ms)
local ApplyingMedicalDamage = false -- Flag to prevent wound detection during medical damage
local LastWeaponDamageTime = {} -- Track last damage time per weapon to prevent duplicates
local LimbEffects = {
    movementPenalty = 0.0,
    onMorphine = 0,
    wasOnMorphine = false,
    legCount = 0,
    armCount = 0,
    headCount = 0
}


--=========================================================
-- EFFICIENT WEAPON DETECTION SYSTEM
--=========================================================
local function FindActualWeaponUsed()
    -- Enhanced weapon detection: check what nearby peds are actually doing
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local weaponFound = nil
    
    -- Check nearby peds (both players and NPCs) for actual combat actions
    local nearbyPeds = {}
    
    -- Add all players
    local players = GetActivePlayers()
    for _, playerId in ipairs(players) do
        if playerId ~= PlayerId() then
            local otherPed = GetPlayerPed(playerId)
            if DoesEntityExist(otherPed) then
                table.insert(nearbyPeds, otherPed)
            end
        end
    end
    
    -- Add nearby NPCs
    local handle, ped = FindFirstPed()
    local success
    repeat
        if DoesEntityExist(ped) and ped ~= playerPed and not IsPedAPlayer(ped) then
            local distance = #(playerCoords - GetEntityCoords(ped))
            if distance <= 10.0 then
                table.insert(nearbyPeds, ped)
            end
        end
        success, ped = FindNextPed(handle)
    until not success
    EndFindPed(handle)
    
    -- Check all nearby peds for combat actions
    for _, otherPed in ipairs(nearbyPeds) do
        if DoesEntityExist(otherPed) then
                local distance = #(playerCoords - GetEntityCoords(otherPed))
                
                -- Only check peds within reasonable combat range
                if distance <= 10.0 then
                    local currentWeapon = GetCurrentPedWeapon(otherPed)
                    local isShooting = IsPedShooting(otherPed)
                    local isInMelee = IsPedInMeleeCombat(otherPed)
                    
                    -- Debug info
                    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                        local pedType = IsPedAPlayer(otherPed) and "Player" or "NPC"
                        print(string.format("^5[DETECT] %s: Wpn=%s Shoot=%s Melee=%s (%.1fm)^7", 
                            pedType, tostring(currentWeapon), tostring(isShooting), tostring(isInMelee), distance))
                    end
                    
                    -- Priority 1: If they're shooting with a weapon, use that weapon
                    if isShooting and currentWeapon and currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 1 then
                        -- Validate weapon exists in config
                        if Config.WeaponDamage[currentWeapon] then
                            weaponFound = currentWeapon
                            if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                                print(string.format("^2[WEAPON DETECT] Found shooter with weapon: %s^7", tostring(currentWeapon)))
                            end
                            break
                        end
                    end
                    
                    -- Priority 2: If they're in melee combat, use unarmed or their melee weapon
                    if isInMelee then
                        if currentWeapon == GetHashKey("WEAPON_UNARMED") or not currentWeapon or currentWeapon == 1 then
                            weaponFound = GetHashKey("WEAPON_UNARMED")
                            if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                                print("^2[MELEE] Found unarmed combat^7")
                            end
                        else
                            -- Check if current weapon is a melee weapon
                            if Config.WeaponDamage[currentWeapon] and 
                               (Config.WeaponDamage[currentWeapon].ballisticType == "melee" or 
                                string.find(Config.WeaponDamage[currentWeapon].data or "", "Knife") or
                                string.find(Config.WeaponDamage[currentWeapon].data or "", "Hatchet")) then
                                weaponFound = currentWeapon
                                if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                                    print(string.format("^2[WEAPON DETECT] Found melee weapon: %s^7", tostring(currentWeapon)))
                                end
                            else
                                weaponFound = GetHashKey("WEAPON_UNARMED")
                            end
                        end
                        break
                    end
                end
        end
    end
    
    -- Check if anyone nearby is actually in melee combat OR if it's an animal attack (priority check)
    local meleeDetected = false
    local animalAttackDetected = false
    for _, otherPed in ipairs(nearbyPeds) do
        if DoesEntityExist(otherPed) then
            local distance = #(playerCoords - GetEntityCoords(otherPed))
            if distance <= 3.0 then
                -- Check for animal attacks first (only for actual animals, not human NPCs)
                if not IsPedAPlayer(otherPed) then
                    local isHuman = IsPedHuman(otherPed)
                    local isAnimal = GetIsAnimal(otherPed)
                    local model = GetEntityModel(otherPed)
                    
                    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                        print(string.format("^6[NPC CHECK] Model: %s, Human: %s, Animal: %s, Melee: %s^7", 
                            tostring(model), tostring(isHuman), tostring(isAnimal), tostring(IsPedInMeleeCombat(otherPed))))
                    end
                    
                    if not isHuman and isAnimal and IsPedInMeleeCombat(otherPed) then
                        -- For now, use a simple fallback system until proper integration
                        local animalWeapon = GetHashKey("WEAPON_ANIMAL")
                        
                        -- Animal model to weapon mapping (comprehensive list)
                        local animalWeaponMap = {
                            -- PREDATORS (High damage, high bleeding)
                            [-1392359921] = GetHashKey("WEAPON_WOLF"), -- Wolf (verified model hash)
                            [GetHashKey("a_c_wolf")] = GetHashKey("WEAPON_WOLF"),
                            [GetHashKey("a_c_wolf_medium")] = GetHashKey("WEAPON_WOLF_MEDIUM"),
                            [GetHashKey("a_c_wolf_small")] = GetHashKey("WEAPON_WOLF_SMALL"),
                            [GetHashKey("a_c_cougar")] = GetHashKey("WEAPON_COUGAR"),
                            [GetHashKey("a_c_panther")] = GetHashKey("WEAPON_COUGAR"), -- Panthers use cougar weapon
                            [GetHashKey("a_c_bear_01")] = GetHashKey("WEAPON_BEAR"),
                            [GetHashKey("a_c_bearblack_01")] = GetHashKey("WEAPON_BEAR"),
                            [GetHashKey("a_c_coyote_01")] = GetHashKey("WEAPON_COYOTE"),
                            [GetHashKey("a_c_alligator_01")] = GetHashKey("WEAPON_ALLIGATOR"),
                            [GetHashKey("a_c_alligator_02")] = GetHashKey("WEAPON_ALLIGATOR"),
                            
                            -- VENOMOUS (Special infection mechanics)
                            [GetHashKey("a_c_snake_01")] = GetHashKey("WEAPON_SNAKE"),
                            [GetHashKey("a_c_snake_pelt_01")] = GetHashKey("WEAPON_SNAKE"),
                            [GetHashKey("a_c_snake_rattlesnake_01")] = GetHashKey("WEAPON_SNAKE"),
                            [GetHashKey("a_c_snake_blrat_01")] = GetHashKey("WEAPON_SNAKE"),
                            
                            -- LARGE HERBIVORES (Trampling/charging attacks)
                            [GetHashKey("a_c_horse_01")] = GetHashKey("WEAPON_HORSE"),
                            [GetHashKey("a_c_horse_americanpaint_greyovero")] = GetHashKey("WEAPON_HORSE"),
                            [GetHashKey("a_c_horse_americanpaint_overo")] = GetHashKey("WEAPON_HORSE"),
                            [GetHashKey("a_c_deer_01")] = GetHashKey("WEAPON_DEER"),
                            [GetHashKey("a_c_elk_01")] = GetHashKey("WEAPON_DEER"), -- Elk use deer weapon
                            [GetHashKey("a_c_moose_01")] = GetHashKey("WEAPON_DEER"), -- Moose use deer weapon
                            [GetHashKey("a_c_buffalo_01")] = GetHashKey("WEAPON_DEER"), -- Buffalo use deer weapon
                            [GetHashKey("a_c_buffalo_tatanka_01")] = GetHashKey("WEAPON_DEER"),
                            
                            -- SMALL AGGRESSIVE ANIMALS
                            [GetHashKey("a_c_fox_01")] = GetHashKey("WEAPON_FOX"),
                            [GetHashKey("a_c_badger_01")] = GetHashKey("WEAPON_BADGER"),
                            [GetHashKey("a_c_raccoon_01")] = GetHashKey("WEAPON_RACCOON"),
                            [GetHashKey("a_c_skunk_01")] = GetHashKey("WEAPON_RACCOON"), -- Skunks use raccoon weapon
                            [GetHashKey("a_c_beaver_01")] = GetHashKey("WEAPON_RACCOON"), -- Beavers use raccoon weapon
                            [GetHashKey("a_c_muskrat_01")] = GetHashKey("WEAPON_MUSKRAT"),
                            
                            -- BIRDS OF PREY (Rare but possible)
                            [GetHashKey("a_c_eagle_01")] = GetHashKey("WEAPON_FOX"), -- Eagles use fox weapon
                            [GetHashKey("a_c_hawk_01")] = GetHashKey("WEAPON_FOX"), -- Hawks use fox weapon
                            [GetHashKey("a_c_vulture_01")] = GetHashKey("WEAPON_FOX"), -- Vultures use fox weapon
                        }
                        
                        if animalWeaponMap[model] then
                            animalWeapon = animalWeaponMap[model]
                        end
                        
                        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                            print(string.format("^6[ANIMAL CHECK] Model: %s, AnimalWeapon: %s^7", tostring(model), tostring(animalWeapon)))
                        end
                        
                        if animalWeapon then
                            weaponFound = animalWeapon
                            animalAttackDetected = true
                            if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                                print(string.format("^1[ANIMAL] Detected %s attack (Model: %s)^7", tostring(animalWeapon), tostring(model)))
                            end
                            break
                        end
                    end
                end
                
                -- Check for regular melee combat (only for humans)
                if IsPedInMeleeCombat(otherPed) and (IsPedAPlayer(otherPed) or IsPedHuman(otherPed)) then
                    meleeDetected = true
                    if not weaponFound then
                        weaponFound = GetHashKey("WEAPON_UNARMED")
                        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                            print("^2[MELEE] Detected nearby melee combat - forcing unarmed^7")
                        end
                    end
                    break
                end
            end
        end
    end
    
    -- Check for ragdoll falls (when RedM engine doesn't flag WEAPON_FALL properly)
    if not weaponFound and not meleeDetected and not animalAttackDetected then
        if IsPedRagdoll(playerPed) then
            weaponFound = GetHashKey("WEAPON_FALL")
            if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                print("^3[RAGDOLL FALL] Detected ragdoll state - assuming fall damage^7")
            end
        end
    end
    
    -- Fallback: If no active combat detected and no melee/animal attacks detected, check damage flags (old method)
    if not weaponFound and not meleeDetected and not animalAttackDetected then
        for weaponHash, weaponData in pairs(Config.WeaponDamage) do
            if HasEntityBeenDamagedByWeapon(playerPed, weaponHash, 0) then
                weaponFound = weaponHash
                if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                    print(string.format("^3[FALLBACK] Using damage flag: %s (%s)^7", tostring(weaponHash), weaponData.data or "unknown"))
                end
                -- Clear the damage flag
                ClearEntityLastDamageEntity(playerPed)
                HasEntityBeenDamagedByWeapon(playerPed, weaponHash, 2)
                break
            end
        end
    end
    
    return weaponFound
end

local function FindNearbyShooter()
    -- Enhanced shooter detection that returns detailed information for bullet penetration system
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local shooterInfo = {
        found = false,
        entity = nil,
        distance = 0,
        isPlayer = false,
        weaponHash = nil,
        coords = nil
    }
    
    -- Check for nearby players first (they take priority)
    local players = GetActivePlayers()
    for _, playerId in ipairs(players) do
        if playerId ~= PlayerId() then
            local otherPlayerPed = GetPlayerPed(playerId)
            if DoesEntityExist(otherPlayerPed) then
                local distance = #(playerCoords - GetEntityCoords(otherPlayerPed))
                if distance <= 100.0 then -- Extended range for bullet penetration calculations
                    -- Check if this player was targeting us or shooting
                    local isTargetingUs = false
                    local hasWeapon, currentWeapon = GetCurrentPedWeapon(otherPlayerPed, true)
                    
                    -- Check if they're aiming at us
                    local isAiming, targetEntity = GetEntityPlayerIsFreeAimingAt(playerId)
                    if isAiming and targetEntity == playerPed then
                        isTargetingUs = true
                    end
                    
                    if (IsPedInCombat(otherPlayerPed, playerPed) or IsPedShooting(otherPlayerPed) or isTargetingUs) and hasWeapon then
                        local playerCoords2 = GetEntityCoords(otherPlayerPed)
                        local calculatedDistance = #(playerCoords - playerCoords2)
                        
                        shooterInfo = {
                            found = true,
                            entity = otherPlayerPed,
                            distance = calculatedDistance,
                            isPlayer = true,
                            weaponHash = currentWeapon,
                            coords = playerCoords2
                        }
                        
                        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                            print(string.format("^4[SHOOTER DEBUG] Player Shooter found - Distance: %.2fm, Targeting: %s^7", 
                                calculatedDistance, tostring(isTargetingUs)))
                        end
                        break
                    end
                end
            end
        end
    end
    
    -- If no player shooter found, check NPCs/peds
    if not shooterInfo.found then
        local nearbyPeds = GetGamePool('CPed')
        for i = 1, math.min(#nearbyPeds, 30) do -- Increased limit for better detection
            local ped = nearbyPeds[i]
            if ped ~= playerPed and DoesEntityExist(ped) then
                -- Skip dead peds unless very recent
                if not IsEntityDead(ped) or (IsEntityDead(ped) and GetEntityHealth(ped) > 0) then
                    local distance = #(playerCoords - GetEntityCoords(ped))
                    if distance <= 100.0 then -- Extended range
                        -- Better NPC shooter detection
                        local hasWeapon, currentWeapon = GetCurrentPedWeapon(ped, true)
                        local isShooting = IsPedShooting(ped)
                        local inCombat = IsPedInCombat(ped, playerPed)
                        
                        if (inCombat or isShooting) and hasWeapon and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
                            local pedCoords = GetEntityCoords(ped)
                            local calculatedDistance = #(playerCoords - pedCoords)
                            
                            shooterInfo = {
                                found = true,
                                entity = ped,
                                distance = calculatedDistance,
                                isPlayer = false,
                                weaponHash = currentWeapon,
                                coords = pedCoords
                            }
                            
                            if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                                print(string.format("^4[SHOOTER DEBUG] NPC Shooter found - Distance: %.2fm, Combat: %s, Shooting: %s^7", 
                                    calculatedDistance, tostring(inCombat), tostring(isShooting)))
                            end
                            break
                        elseif IsPedAPlayer(ped) and distance <= 50.0 then
                            -- Double-check for players that might have been missed
                            local hasWeapon, weaponHash = GetCurrentPedWeapon(ped, true)
                            if hasWeapon and weaponHash ~= GetHashKey("WEAPON_UNARMED") then
                                shooterInfo = {
                                    found = true,
                                    entity = ped,
                                    distance = distance,
                                    isPlayer = true,
                                    weaponHash = weaponHash,
                                    coords = GetEntityCoords(ped)
                                }
                                
                                if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                                    print(string.format("^4[SHOOTER DEBUG] Player found in NPC scan - Distance: %.2fm^7", distance))
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    
    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        print(string.format("^4[SHOOTER] Found:%s Dist:%.1f Player:%s Weapon:%s^7", 
            tostring(shooterInfo.found), shooterInfo.distance, tostring(shooterInfo.isPlayer), 
            shooterInfo.weaponHash and tostring(shooterInfo.weaponHash) or "none"))
    end
    
    return shooterInfo
end

--=========================================================
-- BULLET PENETRATION CALCULATION SYSTEM
--=========================================================
local function CalculateBulletPenetration(weaponData, shooterInfo)
    -- Default penetration data for fallback
    local penetrationResult = {
        status = "through",          -- "through", "stuck", "fragmented"
        bulletCount = 1,             -- Number of bullet fragments/pieces
        metadata = {
            distance = 0,
            weaponType = "Unknown",
            penetrationType = "through",
            requiresSurgery = false,
            description = locale('wound_bullet_passthrough')
        }
    }
    
    -- If ballistics system is disabled, use fallback
    if not Config.Ballistics or not Config.Ballistics.enabled then
        return penetrationResult
    end
    
    -- If no shooter info, use fallback (assume medium range)
    if not shooterInfo or not shooterInfo.distance or shooterInfo.distance <= 0 then
        -- Use fallback distance for unknown shooter scenarios
        if shooterInfo then
            shooterInfo.distance = 20.0 -- Default medium range
        end
        if not shooterInfo then
            return penetrationResult -- Complete fallback to default through-shot
        end
    end
    
    -- Get ballistic type from weaponData
    local ballisticType = weaponData.ballisticType or "pistol"
    local ballisticConfig = Config.Ballistics.weaponCategories[ballisticType]
    if not ballisticConfig then
        return penetrationResult
    end
    
    local distance = shooterInfo.distance
    
    -- Determine distance range based on ballistics config
    local rangeType = "shortRange"
    if distance > Config.Ballistics.ranges.longRange then
        rangeType = "extremeRange"
    elseif distance > Config.Ballistics.ranges.mediumRange then
        rangeType = "longRange"
    elseif distance > Config.Ballistics.ranges.shortRange then
        rangeType = "mediumRange"
    end
    
    -- Get lodging chance for this distance and weapon type
    local lodgingChance = ballisticConfig[rangeType] or 0
    local isLodged = math.random(100) <= lodgingChance
    
    -- Determine status and description
    local status = isLodged and "stuck" or "through"
    local bulletCount = 1
    local requiresSurgery = isLodged
    local description = ""
    
    -- Handle special weapon types
    if ballisticType == "shotgun" and ballisticConfig.usePelletSystem then
        -- Shotgun pellet system
        local pelletCount = ballisticConfig.pelletCount or 9
        local embedPercent = lodgingChance / 100
        local embedCount = math.floor(pelletCount * embedPercent)
        
        if embedCount > 0 then
            status = "fragmented"
            bulletCount = embedCount
            requiresSurgery = true
            description = string.format(locale('cl_desc_fmt_pellets_embedded'), embedCount)
        else
            status = "through"
            requiresSurgery = false
            description = locale('wound_pellets_passthrough')
        end
    else
        -- Regular bullet system
        if isLodged then
            description = locale('wound_bullet_lodged')
        else
            description = locale('wound_entry_exit')
        end
    end
    
    -- Build result
    penetrationResult = {
        status = status,
        bulletCount = bulletCount,
        metadata = {
            distance = distance,
            weaponType = weaponData.data or "Unknown",
            ballisticType = ballisticType,
            rangeType = rangeType,
            lodgingChance = lodgingChance,
            penetrationType = status,
            requiresSurgery = requiresSurgery,
            description = description,
            shooterType = shooterInfo.isPlayer and "player" or "npc",
            fragmentCount = bulletCount > 1 and bulletCount or nil
        }
    }
    
    if Config.Ballistics and Config.Ballistics.debugMode then
        print(string.format("^4[BALLISTICS DEBUG] %s (%s) at %.1fm: %s%% chance, result: %s (%d pieces)^7", 
            weaponData.data or "Unknown", ballisticType, distance, lodgingChance, status, bulletCount))
    end
    
    return penetrationResult
end


local function UpdateGlobalBleeding()
    BleedingLevel = 0
    for _, wound in pairs(PlayerWounds) do
        BleedingLevel = BleedingLevel + wound.bleedingLevel
    end
    BleedingLevel = math.min(BleedingLevel, 10)
end

--=========================================================
-- SCAR SYSTEM - Convert fully healed wounds to scars
--=========================================================
local function CheckAndConvertToScars()
    local scarCount = 0
    
    for bodyPart, wound in pairs(PlayerWounds) do
        -- Convert to scar if both pain and bleeding are 0 and not already a scar
        if (tonumber(wound.painLevel) <= 0 and tonumber(wound.bleedingLevel) <= 0) and not wound.isScar then
            wound.isScar = true
            wound.scarTime = GetGameTimer()
            scarCount = scarCount + 1
            
            -- Notify player about scar formation
            local bodyPartConfig = Config.BodyParts[bodyPart]
            if bodyPartConfig then
                lib.notify({
                    title = locale('cl_menu_medical_recovery'),
                    description = string.format(locale('cl_desc_fmt_wound_healed_scar_notify'),
                        bodyPartConfig.label:lower()),
                    type = 'inform',
                    duration = 4000
                })
            end
            
            if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                print(string.format("^5[SCAR SYSTEM] %s wound converted to scar (was: %s)^7", 
                    bodyPart, wound.metadata and wound.metadata.description or "unknown wound"))
            end
        end
    end
    
    -- Sync scar data to server if any scars were created
    if scarCount > 0 then
        TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', PlayerWounds)
    end
    
    return scarCount
end

--=========================================================
-- UTILITY FUNCTIONS
--=========================================================
local function GetDamageTypeDescription(weaponType)
    local descriptions = {
        SmallPistol = "Small caliber gunshot wound",
        LargePistol = "Large caliber pistol wound", 
        Revolver = "Revolver bullet wound",
        HeavyRevolver = "Heavy revolver wound",
        Rifle = "Rifle bullet wound",
        HeavyRifle = "High-powered rifle wound",
        SniperRifle = "High-velocity rifle wound",
        Shotgun = "Shotgun pellet wounds",
        SawedOffShotgun = "Close-range shotgun blast",
        Knife = "Stab wound from blade",
        LargeBlade = "Deep laceration from large blade",
        Hatchet = "Axe wound with tissue damage",
        LargeAnimal = "Animal attack with crushing damage",
        Predator = "Predator bite and claw marks",
        Explosive = "Blast trauma and shrapnel wounds",
        Fire = "Burn injury",
        Fall = "Blunt force trauma from impact",
        BrokenBone = "Fractured bone with internal damage"
    }
    return descriptions[weaponType] or "Unknown injury type"
end

local function GetWoundDescription(weaponType, painLevel, penetrationData)
    -- Determine medical severity
    local severity = ""
    if painLevel <= 2 then severity = "minor"
    elseif painLevel <= 4 then severity = "moderate" 
    elseif painLevel <= 6 then severity = "serious"
    elseif painLevel <= 8 then severity = "severe"
    else severity = "critical"
    end
    
    -- Enhanced weapon descriptions with realistic calibers
    local weaponDescriptions = {
        SmallPistol = ".32 caliber pistol",
        LargePistol = ".45 caliber pistol", 
        SmallRevolver = ".38 caliber revolver",
        LargeRevolver = ".44 Magnum revolver",
        SmallRifle = ".22 caliber rifle",
        LargeRifle = ".30-06 rifle",
        Shotgun = "12-gauge shotgun",
        Bow = "arrow",
        Thrown = "blade",
        BrokenBone = "bone fracture"
    }
    
    local weaponName = weaponDescriptions[weaponType] or weaponType or "unknown weapon"
    
    -- Generate detailed medical descriptions based on ballistic data
    if penetrationData and penetrationData.status then
        local distance = penetrationData.metadata and penetrationData.metadata.distance or 0
        local rangeDesc = ""
        
        -- Determine range for medical context
        if distance > 0 then
            if distance <= 10 then rangeDesc = " at close range"
            elseif distance <= 50 then rangeDesc = " at medium range"
            else rangeDesc = " at long range"
            end
        end
        
        -- Create detailed medical descriptions based on ballistic status
        if penetrationData.status == "through" then
            return string.format("%s %s wound%s with entry and exit wounds. High velocity round passed completely through soft tissue. Monitor for internal bleeding and tissue trauma.", 
                severity:gsub("^%l", string.upper), weaponName, rangeDesc)
                
        elseif penetrationData.status == "stuck" then
            return string.format("%s %s wound%s with lodged projectile. Entry wound visible, no exit wound. Surgical extraction required to prevent infection and further tissue damage. X-ray recommended for projectile location.", 
                severity:gsub("^%l", string.upper), weaponName, rangeDesc)
                
        elseif penetrationData.status == "fragmented" then
            return string.format("%s %s wound%s with multiple fragments embedded in tissue. Fragmentation pattern suggests projectile broke apart on impact. Multiple extraction procedures required for fragment removal.", 
                severity:gsub("^%l", string.upper), weaponName, rangeDesc)
                
        elseif penetrationData.status == "claw_wound" then
            -- Animal attack descriptions
            local animalDescriptions = {
                Predator = "predator attack with deep claw marks and bite trauma. Jagged tissue damage consistent with animal teeth and claws. High infection risk due to oral bacteria contamination.",
                LargeAnimal = "large animal attack with crushing trauma. Blunt force injuries and possible fractures from trampling or charging. Monitor for internal bleeding.",
                SmallPredator = "small predator bite with puncture wounds. Multiple small bite marks with tissue tearing. Moderate infection risk from animal saliva contamination.",
                SmallAnimal = "small animal bite with superficial puncture wounds. Minor tissue damage with low bleeding. Minimal infection risk but tetanus prophylaxis recommended.",
                Venomous = "venomous bite with injection site trauma. Visible fang marks with localized swelling. Immediate antivenom treatment required to prevent systemic poisoning.",
                Animal = "animal attack with tissue trauma. Bite or claw marks requiring wound cleaning and antibiotic treatment."
            }
            
            local attackDesc = animalDescriptions[weaponType] or animalDescriptions.Animal
            return string.format("%s %s", severity:gsub("^%l", string.upper), attackDesc)
                
        elseif penetrationData.status == "fracture" then
            -- Fracture descriptions
            return string.format("%s bone fracture from fall impact. Painful and limits mobility. Requires proper medical treatment and immobilization to heal correctly. May cause instability when weight-bearing.", 
                severity:gsub("^%l", string.upper))
                
        elseif penetrationData.status == "bone_break" then
            -- Bone break descriptions  
            return string.format("%s bone break from high-impact fall. Severe structural damage requiring immediate medical attention. Complete immobilization necessary. Risk of complications without surgical intervention.", 
                severity:gsub("^%l", string.upper))
                
        else
            -- Fallback for other ballistic statuses
            return string.format("%s %s wound%s requiring medical assessment", 
                severity:gsub("^%l", string.upper), weaponName, rangeDesc)
        end
    else
        -- Enhanced descriptions for non-ballistic wounds
        if weaponType == "Shotgun" then
            return string.format("%s shotgun wound with multiple pellet impacts. Pellet pattern analysis suggests close-range discharge. Individual pellet extraction may be required.", severity:gsub("^%l", string.upper))
        elseif weaponType == "Bow" then
            return string.format("%s arrow wound with penetrating projectile. Arrow shaft visible, removal requires careful extraction to prevent further tissue damage.", severity:gsub("^%l", string.upper))
        elseif weaponType == "Thrown" then
            return string.format("%s penetrating wound from thrown weapon. Sharp-force trauma with possible embedded object requiring surgical removal.", severity:gsub("^%l", string.upper))
        else
            -- Fallback for other weapon types
            return string.format("%s %s", severity:gsub("^%l", string.upper), GetDamageTypeDescription(weaponType):lower())
        end
    end
end

--=========================================================
-- WOUND DATA STRUCTURE
--=========================================================
-- PlayerWounds[bodyPart] = {
--     painLevel = 1-10,           -- Based on Config.InjuryStates
--     bleedingLevel = 1-10,       -- Based on Config.InjuryStates  
--     weaponData = "SmallPistol", -- From Config.WeaponDamage.data
--     timestamp = os.time(),      -- When wound occurred
--     isScar = false,             -- When pain=0 and bleeding=0, becomes scar
--     scarTime = nil,             -- When wound became a scar
--     metadata = {
--         weaponName = "Cattleman Revolver",
--         damageType = "Gunshot",
--         description = "Small caliber bullet wound"
--     },
--     treatments = {
--         -- Array of applied treatments with timestamps
--     },
--     infections = {
--         -- Infection data if present
--     }
-- }

--=========================================================
-- WEAPON DAMAGE DETECTION
--=========================================================
local function GetWeaponDamageData(weaponHash)
    for weapon, data in pairs(Config.WeaponDamage) do
        if weapon == weaponHash then
            return data
        end
    end
    return nil
end

local function GetBodyPartFromBone(boneId)
    -- Two-layer mapping system: Bone ID -> Anatomical Part -> Config.BodyParts key
    
    -- Anatomical part mapping for Config.BodyParts compatibility
    local bodyMap = {
        HEAD = 'HEAD',
        NECK = 'NECK', 
        SPINE = 'UPPER_BODY',
        UPPER_BODY = 'UPPER_BODY',
        LOWER_BODY = 'LOWER_BODY',
        LARM = 'LARM',
        RARM = 'RARM',
        LHAND = 'LHAND',
        RHAND = 'RHAND',
        LFINGER = 'LHAND', -- Fingers mapped to hands for Config.BodyParts
        RFINGER = 'RHAND', -- Fingers mapped to hands for Config.BodyParts
        LLEG = 'LLEG',
        RLEG = 'RLEG',
        LFOOT = 'LFOOT',
        RFOOT = 'RFOOT',
        NONE = 'NONE'
    }
    
    -- Complete bone ID to anatomical part mapping
    local boneMap = {
        -- None/Default
        [0] = 'NONE',
        
        -- Head
        [21030] = 'HEAD',
        [21031] = 'HEAD',
        
        -- Neck
        [14283] = 'NECK',
        
        -- Spine
        [14411] = 'SPINE',
        [11569] = 'SPINE',
        [23553] = 'SPINE', 
        [14410] = 'SPINE',
        [14412] = 'SPINE',
        [14413] = 'SPINE',
        [14414] = 'SPINE',
        
        -- Upper Body
        [54802] = 'UPPER_BODY',
        [64729] = 'UPPER_BODY',
        
        -- Lower Body
        [30226] = 'LOWER_BODY',
        [56200] = 'LOWER_BODY',
        
        -- Left Arm
        [37873] = 'LARM',
        [53675] = 'LARM',
        
        -- Left Hand
        [34606] = 'LHAND',
        
        -- Left Fingers
        [41404] = 'LFINGER', 
        [41405] = 'LFINGER',
        [41356] = 'LFINGER',
        [41357] = 'LFINGER',
        [41340] = 'LFINGER',
        [41341] = 'LFINGER',
        [41324] = 'LFINGER',
        [41325] = 'LFINGER',
        [41308] = 'LFINGER',
        [41309] = 'LFINGER',
        [41403] = 'LFINGER',
        [41323] = 'LFINGER',
        [41307] = 'LFINGER',
        [41355] = 'LFINGER',
        [41339] = 'LFINGER',
        
        -- Left Leg
        [65478] = 'LLEG', 
        [55120] = 'LLEG',
        
        -- Left Foot
        [53081] = 'LFOOT',
        [45454] = 'LFOOT',
        
        -- Right Arm
        [46065] = 'RARM',
        [54187] = 'RARM',
        
        -- Right Hand  
        [22798] = 'RHAND',
        
        -- Right Fingers
        [16731] = 'RFINGER',
        [16732] = 'RFINGER',
        [16733] = 'RFINGER',
        [16747] = 'RFINGER',
        [16748] = 'RFINGER',
        [16749] = 'RFINGER',
        [16763] = 'RFINGER',
        [16764] = 'RFINGER',
        [16765] = 'RFINGER',
        [16779] = 'RFINGER',
        [16780] = 'RFINGER',
        [16781] = 'RFINGER',
        [16827] = 'RFINGER',
        [16828] = 'RFINGER',
        [16829] = 'RFINGER',
        
        -- Right Leg
        [6884] = 'RLEG',
        [43312] = 'RLEG',
        
        -- Right Foot
        [41273] = 'RFOOT',
        [33646] = 'RFOOT'
    }
    
    -- Get anatomical part from bone ID
    local anatomicalPart = boneMap[boneId]
    if not anatomicalPart then
        return nil -- Unknown bone
    end
    
    -- Translate anatomical part to Config.BodyParts key
    local bodyPart = bodyMap[anatomicalPart]
    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.printBodyPartMapping then
        print(string.format("^6[BONE] %d → %s^7", boneId, bodyPart or "UNKNOWN"))
    end
    
    return bodyPart
end

--=========================================================
-- MOVEMENT & LIMPING SYSTEM
--=========================================================
local function ProcessMovementEffects()
    local ped = PlayerPedId()
    local hasLegInjury = false
    local maxSeverity = 0
    
    -- Check for leg injuries that cause limping
    for bodyPart, wound in pairs(PlayerWounds) do
        local bodyPartConfig = Config.BodyParts[bodyPart]
        if bodyPartConfig and bodyPartConfig.limp and tonumber(wound.painLevel) > 0 then
            hasLegInjury = true
            maxSeverity = math.max(maxSeverity, wound.painLevel)
        end
    end
    
    -- Apply movement penalties based on injury severity
    if hasLegInjury and LimbEffects.onMorphine <= 0 then
        local movementRate = 1.0 - (maxSeverity * 0.1) -- 10% reduction per pain level
        SetPedMoveRateOverride(ped, math.max(movementRate, 0.3)) -- Minimum 30% speed
        
        -- Handle morphine withdrawal
        if LimbEffects.wasOnMorphine then
            SetPedToRagdoll(ped, 1500, 2000, 3, true, true, false)
            LimbEffects.wasOnMorphine = false
            lib.notify({
                title = locale('qc_health'),
                description = locale('qc_notGood'),
                type = 'error'
            })
        end
    else
        SetPedMoveRateOverride(ped, 1.0)
        
        -- Handle morphine effect
        if not LimbEffects.wasOnMorphine and LimbEffects.onMorphine > 0 then
            LimbEffects.wasOnMorphine = true
            lib.notify({
                title = locale('qc_health'),
                description = locale('qc_painfade'),
                type = 'success'
            })
        end
        
        if LimbEffects.onMorphine > 0 then
            LimbEffects.onMorphine = LimbEffects.onMorphine - 1
        end
    end
end

--=========================================================
-- WOUND CREATION & TRACKING
--=========================================================
function CreateWound(bodyPart, weaponData, weaponHash, shooterInfo)
    if not bodyPart or not weaponData then return end
    
    local bodyPartConfig = Config.BodyParts[bodyPart]
    if not bodyPartConfig then return end
    
    -- Calculate penetration data - handle animal attacks differently than bullets
    local penetrationData
    if weaponData.ballisticType == "animal" then
        -- Animal attacks: claws/teeth/bites - no ballistic penetration
        penetrationData = {
            status = "claw_wound",
            bulletCount = 0,
            metadata = {
                distance = 0,
                weaponType = weaponData.data or "Animal",
                penetrationType = "surface_trauma",
                requiresSurgery = false,
                description = locale('wound_animal_attack')
            }
        }
    elseif weaponData.ballisticType == "environmental" and (weaponData.status == "fracture" or weaponData.status == "bone_break") then
        -- Fractures/bone breaks: structural damage - no ballistic penetration
        penetrationData = {
            status = weaponData.status, -- "fracture" or "bone_break"
            bulletCount = 0,
            metadata = {
                distance = 0,
                weaponType = weaponData.data or "Fall",
                penetrationType = "structural_damage",
                requiresSurgery = weaponData.status == "bone_break", -- Bone breaks may need surgery
                description = weaponData.status == "bone_break" and locale('wound_bone_break_severe') or locale('wound_bone_fracture')
            }
        }
    else
        -- Regular weapons: calculate bullet penetration
        penetrationData = CalculateBulletPenetration(weaponData, shooterInfo)
    end
    
    -- Determine bleeding based on wound outcome (RP-friendly approach)
    local bleedingLevel = 0
    if penetrationData.status == "claw_wound" then
        -- Animal attacks: direct tissue damage with consistent bleeding
        bleedingLevel = weaponData.bleeding
    elseif penetrationData.status == "through" then
        -- Shot-through wounds: consistent bleeding at config level (good for RP)
        bleedingLevel = weaponData.bleeding
    elseif penetrationData.status == "stuck" then
        -- Lodged bullets: minimal bleeding initially (bullet acts as temporary plug)
        -- Note: When bullet is surgically removed, bleeding should increase to full amount
        bleedingLevel = math.max(1, math.ceil(weaponData.bleeding * 0.4))
    elseif penetrationData.status == "fragmented" then
        -- Fragmented bullets/pellets: consistent bleeding (multiple small wounds)
        bleedingLevel = weaponData.bleeding
    else
        -- Fallback: always bleed at config level (remove RNG for consistency)
        bleedingLevel = weaponData.bleeding
    end
    
    -- Calculate dynamic pain level (bleeding + tissue damage)
    local calculatedPain = bleedingLevel + 1 -- Pain = bleeding + tissue damage
    
    -- Special handling for unarmed combat - reduce pain significantly
    if weaponData.data == "Unarmed" then
        calculatedPain = math.max(0.5, calculatedPain * 0.3) -- Reduce unarmed pain to 30% of normal
    end
    
    -- Debug wound calculation
    if Config.Ballistics and Config.Ballistics.debugMode then
        local debugType = weaponData.ballisticType == "animal" and "ANIMAL ATTACK" or "BALLISTICS"
        print(string.format("^4[%s] %s: %s → Bleed:%d^7", 
            debugType, weaponData.data or "Unknown", penetrationData.status, bleedingLevel))
    end
    
    -- Create enhanced wound metadata with bullet penetration info
    local metadata = {
        weaponHash = weaponHash,
        weaponType = weaponData.data,
        damageType = GetDamageTypeDescription(weaponData.data),
        description = GetWoundDescription(weaponData.data, calculatedPain, penetrationData),
        timestamp = GetGameTimer(),
        -- BULLET PENETRATION METADATA (Medical examination findings)
        bulletStatus = penetrationData.status,
        requiresSurgery = penetrationData.metadata.requiresSurgery,
        caliber = penetrationData.metadata.weaponType, -- Doctors can determine caliber from wound
        medicalDescription = penetrationData.metadata.description,
        -- Internal tracking (not visible to doctors)
        _internal = {
            shooterDistance = shooterInfo and shooterInfo.distance or nil,
            shooterType = shooterInfo and (shooterInfo.isPlayer and "player" or "npc") or "unknown"
        }
    }
    
    -- Bandages don't absorb damage - they're medical treatments, not armor
    -- Wounds can still occur on bandaged parts, but we'll track this for notifications

    -- Initialize or accumulate existing wound damage
    if not PlayerWounds[bodyPart] then
        -- Calculate health for new wound
        local currentHealth, maxHealth, healthPercentage = CalculateBodyPartHealth(bodyPart, calculatedPain, bleedingLevel)
        
        -- Create new wound with health data
        PlayerWounds[bodyPart] = {
            painLevel = calculatedPain,
            bleedingLevel = bleedingLevel,
            currentHealth = currentHealth,
            maxHealth = maxHealth,
            healthPercentage = healthPercentage,
            weaponData = weaponData.data,
            timestamp = GetGameTimer(),
            isScar = false,
            scarTime = nil,
            metadata = metadata,
            treatments = {},
            infections = {}
        }
    else
        -- Accumulate damage on existing wound (multiple hits to same body part)
        local existingWound = PlayerWounds[bodyPart]
        
        -- Add new damage to existing levels (cap at 10)
        existingWound.bleedingLevel = math.min(existingWound.bleedingLevel + bleedingLevel, 10)
        existingWound.painLevel = math.min(existingWound.bleedingLevel + 1, 10) -- Recalculate pain based on total bleeding
        
        -- Recalculate health with new damage levels
        local currentHealth, maxHealth, healthPercentage = CalculateBodyPartHealth(bodyPart, existingWound.painLevel, existingWound.bleedingLevel)
        existingWound.currentHealth = currentHealth
        existingWound.maxHealth = maxHealth
        existingWound.healthPercentage = healthPercentage
        
        -- Update metadata to reflect latest weapon hit
        existingWound.metadata = metadata
        existingWound.weaponData = weaponData.data
        
        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
            print(string.format("^6[WOUND ACCUMULATION] %s hit again! Pain: %d, Bleeding: %d, Health: %.1f%%^7", 
                bodyPart, existingWound.painLevel, existingWound.bleedingLevel, healthPercentage))
        end
    end
    
    -- Notify player of wound (new or accumulated)
    local currentWound = PlayerWounds[bodyPart]
    local injuryState = Config.InjuryStates[currentWound.painLevel]
    if injuryState then
        lib.notify({
            title = locale('qc_health'),
            description = string.format(locale('cl_desc_fmt_wound_suffered'),
                injuryState.pain,
                bodyPartConfig.label
            ),
            type = 'error',
            duration = 5000
        })
    end
    
    -- Update global bleeding level
    UpdateGlobalBleeding()
    
    -- Sync wound data to server for persistence
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', PlayerWounds)
    
    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        local wound = PlayerWounds[bodyPart]
        if wound then
            print(string.format("^2[BODY HEALTH] %s health: %.1f%% (%.1f/%.1f)^7", 
                bodyPart, 
                wound.healthPercentage or 100,
                wound.currentHealth or 100,
                wound.maxHealth or 100))
        end
    end
    
    -- Trigger screen effects for major wounds
    if calculatedPain >= 5 then
        AnimpostfxPlay("PlayerHealthCrackpot")
    end
end




--=========================================================
-- WOUND PROGRESSION & HEALING SYSTEM
--=========================================================
local LastProgressionCheck = {
    bleeding = 0,
    pain = 0,
    bandageHealing = 0,
    naturalHealing = 0
}

-- UNIFIED MEDICAL PROGRESSION SYSTEM
-- Handles wound progression, bandage decay, and infection in single efficient loop
local function ProcessUnifiedMedicalProgression()
    if not Config.WoundProgression and not Config.InfectionSystem.enabled then
        return
    end
    
    local currentTime = GetGameTimer()
    local activeTreatments = ActiveTreatments or {}
    local woundsChanged = false
    local infectionsChanged = false
    
    if Config.WoundSystem.debugging.enabled then
        local woundCount = 0
        local treatmentCount = 0
        for _ in pairs(PlayerWounds or {}) do woundCount = woundCount + 1 end
        for _ in pairs(activeTreatments or {}) do treatmentCount = treatmentCount + 1 end
        print(string.format("^6[PROGRESSION] Processing %d wounds, %d treatments^7", 
            woundCount, treatmentCount))
    end
    
    for bodyPart, wound in pairs(PlayerWounds) do
        if wound.isScar then goto continue end -- Skip scars
        
        local treatment = activeTreatments[bodyPart]
        local hasBandage = treatment and treatment.treatmentType == "bandage" and treatment.isActive
        
        -- STEP 1: SIMPLE TIME-BASED BANDAGE EXPIRATION (NO 50% RETURN)
        if hasBandage and treatment.isActive then
            if currentTime >= treatment.expirationTime then
                -- Bandage has expired - just mark as expired, no wound level changes
                treatment.isActive = false -- Mark as expired
                treatment.expiredTime = currentTime -- Start infection risk timer
                woundsChanged = true
                
                if Config.WoundSystem.debugging.enabled then
                    print(string.format("^3[BANDAGE EXPIRED] %s bandage expired - now allowing bleeding progression^7", bodyPart))
                end
                
                -- Notify player of bandage expiration
                lib.notify({
                    title = locale('cl_menu_bandage_expired'),
                    description = string.format(locale('cl_desc_fmt_wound_bandage_expired'),
                        Config.BodyParts[bodyPart] and Config.BodyParts[bodyPart].label or bodyPart),
                    type = 'warning',
                    duration = 8000
                })
            end
        end
        
        -- STEP 2: INFECTION RISK ASSESSMENT (expired bandages on bleeding wounds)
        if Config.InfectionSystem.enabled and hasBandage and not treatment.isActive then
            -- Check if grace period has passed since bandage expired
            local gracePeriodPassed = treatment.expiredTime and 
                (currentTime - treatment.expiredTime) >= (Config.InfectionSystem.dirtyBandageGracePeriod * 1000)
                
            if gracePeriodPassed and tonumber(wound.bleedingLevel) > 0 then
                -- Calculate infection chance based on wound type and bullet metadata
                local baseChance = Config.InfectionSystem.baseInfectionChance
                local multiplier = Config.InfectionSystem.woundTypeMultipliers.default
                
                -- Check for bullet penetration type in wound metadata
                if wound.metadata and wound.metadata.bulletStatus then
                    local bulletType = "bullet_" .. wound.metadata.bulletStatus
                    multiplier = Config.InfectionSystem.woundTypeMultipliers[bulletType] or multiplier
                end
                
                local finalChance = baseChance * multiplier
                local roll = math.random(1, 100)
                
                if roll <= finalChance then
                    -- Start or progress infection
                    local currentInfection = PlayerInfections[bodyPart] or { percentage = 0, stage = 0 }
                    currentInfection.percentage = math.min(currentInfection.percentage + Config.InfectionSystem.infectionPercentagePerTick, 100)
                    
                    -- Determine infection stage based on percentage
                    local newStage = 0
                    for stageNum, stageData in pairs(Config.InfectionSystem.stages) do
                        if currentInfection.percentage >= stageData.minPercent then
                            newStage = stageNum
                        end
                    end
                    
                    if newStage > currentInfection.stage then
                        currentInfection.stage = newStage
                        local stageInfo = Config.InfectionSystem.stages[newStage]
                        
                        -- Notify player of infection progression
                        lib.notify({
                            title = stageInfo.name,
                            description = stageInfo.symptom,
                            type = 'error',
                            duration = 10000
                        })
                        
                        if Config.WoundSystem.debugging.enabled then
                            print(string.format("^1[INFECTION] %s reached stage %d (%d%%) - %s^7", 
                                bodyPart, newStage, currentInfection.percentage, stageInfo.name))
                        end
                    end
                    
                    PlayerInfections[bodyPart] = currentInfection
                    infectionsChanged = true
                    
                elseif Config.WoundSystem.debugging.enabled then
                    print(string.format("^3[INFECTION ROLL] %s: %d/%d (%.1fx multiplier, %s)^7", 
                        bodyPart, roll, finalChance, multiplier, wound.metadata and wound.metadata.bulletStatus or "default"))
                end
            end
        end
        
        -- STEP 3: WOUND PROGRESSION (untreated wounds worsen)
        local bleedingLevel = tonumber(wound.bleedingLevel) or 0
        if not hasBandage and tonumber(bleedingLevel) > 0 then
            local progressionChance = Config.WoundProgression and Config.WoundProgression.painProgressionChance or 0.15
            progressionChance = progressionChance + (bleedingLevel * 0.05) -- Higher bleeding = higher chance
            
            if math.random() <= progressionChance then
                local oldPain = wound.painLevel
                local oldBleeding = bleedingLevel
                
                -- Untreated wounds get worse
                wound.painLevel = math.min(wound.painLevel + 0.5, 10)
                if math.random() <= 0.3 then -- 30% chance bleeding also increases
                    wound.bleedingLevel = math.min(wound.bleedingLevel + 0.5, 10)
                end
                
                if Config.WoundSystem.debugging.enabled then
                    print(string.format("^1[WOUND PROGRESSION] %s worsened: Pain %.1f->%.1f, Bleeding %.1f->%.1f^7", 
                        bodyPart, oldPain, wound.painLevel, oldBleeding, wound.bleedingLevel))
                end
                
                -- Notify player of wound worsening
                lib.notify({
                    title = locale('cl_menu_wound_worsening'),
                    description = string.format(locale('cl_desc_fmt_wound_getting_worse'),
                        Config.BodyParts[bodyPart] and Config.BodyParts[bodyPart].label:lower() or bodyPart),
                    type = 'error',
                    duration = 8000
                })
                
                woundsChanged = true
            end
        end
        
        -- STEP 4: WOUND HEALING SYSTEM (bandaged wounds at bleeding level 1)
        -- This is handled by the dedicated wound healing system
        
        -- STEP 5: NATURAL HEALING (only fully healed wounds become scars)
        if tonumber(wound.painLevel) <= 2 and tonumber(wound.bleedingLevel) <= 1 and not hasBandage then
            -- Gradual healing to scar formation
            wound.painLevel = math.max(wound.painLevel - 0.1, 0)
            wound.bleedingLevel = math.max(wound.bleedingLevel - 0.1, 0)
            
            if tonumber(wound.painLevel) <= 0 and tonumber(wound.bleedingLevel) <= 0 then
                wound.isScar = true
                wound.scarTime = currentTime
                woundsChanged = true
                
                if Config.WoundSystem.debugging.enabled then
                    print(string.format("^2[SCAR FORMATION] %s wound fully healed -> scar^7", bodyPart))
                end
            end
        end
        
        ::continue::
    end
    
    -- UPDATE SERVER DATA if changes occurred
    if woundsChanged then
        UpdateGlobalBleeding()
        TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', PlayerWounds)
    end
    
    if infectionsChanged then
        TriggerServerEvent('QC-AdvancedMedic:server:UpdateInfectionData', PlayerInfections)
    end
    
    -- Process wound healing system (bandaged wounds at bleeding level 1)
    if Config.WoundHealing and Config.WoundHealing.enabled and ProcessWoundHealing then
        ProcessWoundHealing()
    end
    
    if Config.WoundSystem.debugging.enabled and (woundsChanged or infectionsChanged) then
        print(string.format("^6[PROGRESSION] Complete - Wounds:%s Infections:%s^7", 
            woundsChanged and "Updated" or "NoChange", infectionsChanged and "Updated" or "NoChange"))
    end
end

--=========================================================
-- MAIN DAMAGE DETECTION LOOP
--=========================================================
CreateThread(function()
    -- Wait for player to be logged in
    repeat Wait(1000) until LocalPlayer.state['isLoggedIn']
    
    print("^2[QC-AdvancedMedic] Wound system initialized and running^7")
    
    while true do
        local ped = PlayerPedId()
        local currentTime = GetGameTimer()
        
        if not PlayerHealth then
            PlayerHealth = GetEntityHealth(ped)
        end
        
        local currentHealth = GetEntityHealth(ped)
        
        -- Check for new damage (with cooldown to prevent spam)
        -- Skip wound detection if we're applying medical damage (bleeding, infections, etc.)
        if currentHealth < PlayerHealth and (currentTime - LastDamageTime > DAMAGE_COOLDOWN) then
            if ApplyingMedicalDamage then
                if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                    print(string.format("^5[MEDICAL DAMAGE BLOCK] Wound creation blocked: %d -> %d (medical damage in progress)^7", PlayerHealth, currentHealth))
                end
                PlayerHealth = currentHealth -- Update health without creating wounds
                goto skip_wound_creation
            end
            
            LastDamageTime = currentTime
            
            if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                print(string.format("^1[DAMAGE] Health: %d → %d^7", PlayerHealth, currentHealth))
            end
            
            -- EARLY NEEDS FILTER: Check for hunger/thirst damage before processing wounds
            -- This catches needs damage that may not register bone hits
            local playerData = RSGCore.Functions.GetPlayerData()
            if playerData and playerData.metadata then
                local hunger = playerData.metadata.hunger or 100
                local thirst = playerData.metadata.thirst or 100
                
                -- If player has hunger/thirst at 0, this is likely needs damage
                if hunger <= 0 or thirst <= 0 then
                    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                        print(string.format("^6[NEEDS FILTER] Ignoring health change - hunger/thirst damage (H:%d, T:%d)^7", 
                            math.floor(hunger), math.floor(thirst)))
                    end
                    goto skip_wound_creation
                end
            end
            
            local hit, boneId = GetPedLastDamageBone(ped)
            
            if hit then
                
                -- Get actual weapon that damaged us (efficient method)
                local weaponHash = FindActualWeaponUsed()
                
                -- Get detailed shooter information for bullet penetration system
                local shooterInfo = FindNearbyShooter()
                local hasNearbyShooter = shooterInfo.found
                
                -- Priority override: If shooter found with weapon, use their weapon instead
                if shooterInfo.found and shooterInfo.weapon then
                    weaponHash = shooterInfo.weapon
                end
                
                if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                    print(string.format("^3[WEAPON] Hash: %s^7", tostring(weaponHash)))
                end
                
                local weaponData = GetWeaponDamageData(weaponHash)
                local bodyPart = GetBodyPartFromBone(boneId)
                
                -- Override bone detection for NON-RAGDOLL falls only (they land on feet)
                if weaponHash == GetHashKey("WEAPON_FALL") then
                    local isRagdoll = IsPedRagdoll(PlayerPedId())
                    
                    if not isRagdoll then
                        -- Non-ragdoll falls: override to feet/legs since they just landed normally
                        local velocity = GetEntityVelocity(PlayerPedId())
                        local speed = math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2)
                        
                        if speed > 4.0 then
                            -- Higher speed non-ragdoll falls - can hit legs or lower body
                            local fallParts = {"RLEG", "LLEG", "LOWER_BODY", "RLEG", "LLEG"} -- Bias toward legs
                            bodyPart = fallParts[math.random(#fallParts)]
                        else
                            -- Lower speed non-ragdoll falls - feet only
                            local fallParts = {"RLEG", "LLEG"} -- Feet only
                            bodyPart = fallParts[math.random(#fallParts)]
                        end
                        
                        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                            print(string.format("^5[NON-RAGDOLL FALL OVERRIDE] Speed: %.1f -> %s (was %s from bone %s)^7", 
                                speed, bodyPart, GetBodyPartFromBone(boneId), tostring(boneId)))
                        end
                    else
                        -- Ragdoll falls: keep the actual bone hit (head, hands, etc.) - more realistic
                        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                            print(string.format("^6[RAGDOLL FALL] Keeping actual bone hit: %s (bone %s)^7", 
                                bodyPart, tostring(boneId)))
                        end
                    end
                end
                
                if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                    print(string.format("^7[WOUND] %s from %s^7", tostring(bodyPart), weaponData and weaponData.data or "Unknown"))
                end
                
                if weaponData and bodyPart then
                    -- Handle environmental damage (falls) - enhanced like animal attacks
                    if weaponData.ballisticType == "environmental" then
                        CreateWound(bodyPart, weaponData, weaponHash, nil)
                        
                        -- Trigger environmental damage processing (like animal attacks)
                        if weaponHash == GetHashKey("WEAPON_FALL") and HandleEnvironmentalDamage then
                            local isRagdoll = IsPedRagdoll(PlayerPedId())
                            HandleEnvironmentalDamage("fall", bodyPart, isRagdoll)
                        end
                    -- Handle animal attacks (use bone detection but trigger infection)
                    elseif weaponData.ballisticType == "animal" then
                        CreateWound(bodyPart, weaponData, weaponHash, nil)
                        
                        -- Find the attacking animal model for infection handling
                        local attackingAnimal = nil
                        local ped = PlayerPedId()
                        local playerCoords = GetEntityCoords(ped)
                        
                        local handle, animal = FindFirstPed()
                        local success
                        repeat
                            if DoesEntityExist(animal) and animal ~= ped and not IsPedAPlayer(animal) then
                                local distance = #(playerCoords - GetEntityCoords(animal))
                                if distance <= 3.0 and IsPedInMeleeCombat(animal) then
                                    attackingAnimal = GetEntityModel(animal)
                                    break
                                end
                            end
                            success, animal = FindNextPed(handle)
                        until not success
                        EndFindPed(handle)
                        
                        -- Trigger infection handling if we found the attacking animal
                        if attackingAnimal and HandleAnimalAttackInfection then
                            HandleAnimalAttackInfection(attackingAnimal, bodyPart)
                        end
                        
                        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                            print(string.format("^2[CREATED] %s wound: %s (animal attack)^7", 
                                bodyPart, weaponData.data or "unknown animal"))
                        end
                    else
                        -- For weapon damage, create wound with or without shooter info
                        -- (NPCs may despawn quickly after shooting)
                        if hasNearbyShooter and shooterInfo.distance > 0 then
                            CreateWound(bodyPart, weaponData, weaponHash, shooterInfo)
                            if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                                print(string.format("^2[CREATED] %s wound: %s (%.1fm, %s)^7", 
                                    bodyPart, weaponData.data or "unknown weapon", 
                                    shooterInfo.distance,
                                    shooterInfo.isPlayer and "Player" or "NPC"))
                            end
                        else
                            -- Create wound with default/unknown shooter info for ballistics fallback
                            local fallbackShooterInfo = {
                                found = false,
                                distance = 20.0, -- Assume medium range if unknown
                                isPlayer = false,
                                weaponHash = weaponHash
                            }
                            CreateWound(bodyPart, weaponData, weaponHash, fallbackShooterInfo)
                            if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                                print(string.format("^2[CREATED] %s wound: %s (%.1fm, fallback)^7", 
                                    bodyPart, weaponData.data or "unknown weapon", 
                                    fallbackShooterInfo.distance))
                            end
                        end
                        
                    end
                else
                    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                        print("^1[WOUND DEBUG] Failed to create wound - missing weapon data or body part^7")
                    end
                end
            else
                -- No bone hit detected - this is likely needs damage, fall damage, or other non-weapon damage
                if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                    print("^1[WOUND DEBUG] Health changed but no bone hit detected^7")
                end
                
                -- Check for non-ragdoll fall damage when no bone hit is detected
                local velocity = GetEntityVelocity(ped)
                local speed = math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2)
                local height = GetEntityHeightAboveGround(ped)
                local isRagdoll = IsPedRagdoll(ped)
                
                -- Non-ragdoll fall detection (no bone hit but health damage)
                if not isRagdoll and (speed > 1.5 or (height > 0.1 and speed > 0.5)) then
                    local weaponData = GetWeaponDamageData(GetHashKey("WEAPON_FALL"))
                    
                    -- Override to feet/legs for non-ragdoll falls
                    local bodyPart
                    if speed > 4.0 then
                        local fallParts = {"RLEG", "LLEG", "LOWER_BODY", "RLEG", "LLEG"}
                        bodyPart = fallParts[math.random(#fallParts)]
                    else
                        local fallParts = {"RLEG", "LLEG"}
                        bodyPart = fallParts[math.random(#fallParts)]
                    end
                    
                    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                        print(string.format("^5[NON-RAGDOLL FALL] No bone hit - Speed: %.1f, Height: %.1f -> %s^7", speed, height, bodyPart))
                    end
                    
                    if weaponData and bodyPart then
                        CreateWound(bodyPart, weaponData, GetHashKey("WEAPON_FALL"), nil)
                        
                        -- Handle environmental damage enhancement
                        if weaponData.ballisticType == "environmental" and HandleEnvironmentalDamage then
                            local isRagdoll = false -- Non-ragdoll falls (no bone hit detected)
                            HandleEnvironmentalDamage("fall", bodyPart, isRagdoll)
                        end
                    end
                end
                
                -- Double-check for needs damage even without bone hits
                local playerData = RSGCore.Functions.GetPlayerData()
                if playerData and playerData.metadata then
                    local hunger = playerData.metadata.hunger or 100
                    local thirst = playerData.metadata.thirst or 100
                    
                    if hunger <= 0 or thirst <= 0 then
                        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                            print(string.format("^6[NEEDS FILTER] Non-bone damage identified as hunger/thirst (H:%d, T:%d)^7", 
                                math.floor(hunger), math.floor(thirst)))
                        end
                        goto skip_wound_creation
                    end
                end
                
                -- Environmental damage - silently skip (reduced debug spam)
            end
        end
        
        ::skip_wound_creation::
        PlayerHealth = currentHealth
        Wait(100) -- Check for damage every 100ms for responsiveness
    end
end)

--=========================================================
-- BLEEDING DAMAGE LOOP (Every 30 seconds - damage from unbandaged wounds)
--=========================================================
CreateThread(function()
    -- Wait for player to be fully loaded and wounds synced before starting bleeding damage
    repeat Wait(1000) until LocalPlayer.state['isLoggedIn']
    Wait(10000) -- Additional 10 second delay to ensure wound data is loaded and synced
    
    local threadId = math.random(1000, 9999)
    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        print(string.format("^6[BLEEDING SYSTEM] Starting bleeding damage loop - 30 second intervals [Thread ID: %d]^7", threadId))
    end
    
    while true do
        Wait(30000) -- 30 seconds like the old system
        
        -- Check if player is logged in and alive (like RSG-Core needs system)
        if not LocalPlayer.state.isLoggedIn then return end
        
        local playerData = RSGCore.Functions.GetPlayerData()
        if not playerData or playerData.metadata['isdead'] then return end
        
        local totalBleedingDamage = 0
        local bleedingWounds = {}
        local protectedWounds = {}
        
        -- Early exit if no wounds exist
        if not next(PlayerWounds) then
            if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                print("^3[BLEEDING DEBUG] No wounds to process - skipping bleeding damage tick^7")
            end
            goto continue_bleeding_loop
        end
        -- Calculate total bleeding damage from all unbandaged wounds
        -- Get active treatments once for efficiency
        local activeTreatments = ActiveTreatments or {}
        
        for bodyPart, wound in pairs(PlayerWounds) do
            -- Skip scars and only process wounds that are actually bleeding
            if not wound.isScar and wound.bleedingLevel and tonumber(wound.bleedingLevel) > 0 then
                local hasBandage = false
                
                -- Check if this body part has an ACTIVE bandage (expired bandages don't protect)
                if activeTreatments and activeTreatments[bodyPart] and 
                   activeTreatments[bodyPart].treatmentType == "bandage" and 
                   activeTreatments[bodyPart].isActive then
                    hasBandage = true
                    table.insert(protectedWounds, bodyPart)
                    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                        print(string.format("^2[BLEEDING PROTECTION] %s wound protected by active %s bandage^7", 
                            bodyPart, activeTreatments[bodyPart].itemType or "unknown"))
                    end
                elseif activeTreatments and activeTreatments[bodyPart] and 
                       activeTreatments[bodyPart].treatmentType == "bandage" and 
                       not activeTreatments[bodyPart].isActive and Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                    print(string.format("^3[BLEEDING DEBUG] %s wound has expired %s bandage - allowing bleeding damage^7", 
                        bodyPart, activeTreatments[bodyPart].itemType or "unknown"))
                end
                
                if not hasBandage then
                    -- Add to total bleeding damage
                    local injuryState = Config.InjuryStates[wound.bleedingLevel]
                    if injuryState and injuryState.bleedingDamagePerTick then
                        totalBleedingDamage = totalBleedingDamage + injuryState.bleedingDamagePerTick
                        table.insert(bleedingWounds, {
                            bodyPart = bodyPart,
                            level = wound.bleedingLevel,
                            damage = injuryState.bleedingDamagePerTick
                        })
                    end
                end
            elseif Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                -- Debug: Show wounds with no bleeding or scars (shouldn't be processed)
                if wound.isScar then
                    print(string.format("^5[BLEEDING DEBUG] %s is a scar - skipping bleeding damage^7", bodyPart))
                else
                    print(string.format("^3[BLEEDING DEBUG] %s wound has no bleeding (level: %d) - skipping^7", 
                        bodyPart, wound.bleedingLevel or 0))
                end
            end
        end
        
        -- Apply total bleeding damage in one hit (using ApplyDamageToPed)
        if totalBleedingDamage > 0 then
            local health = GetEntityHealth(cache.ped)
            
            -- Set flag to prevent wound detection from this medical damage
            ApplyingMedicalDamage = true
            if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                print("^5[MEDICAL DAMAGE] Flag set - blocking wound detection^7")
            end
            
            -- Add pain effect like the working code
            PlayPain(cache.ped, 9, 1, true, true)
            
            -- Use ApplyDamageToPed with proper RedM parameters but scale down damage to prevent instant death
            ApplyDamageToPed(cache.ped, 10, false)
            
            local healthAfter = GetEntityHealth(cache.ped)
                
                if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                    print(string.format("^6[HEALTH DEBUG] Before: %d HP, Calculated: %d damage, Scaled: %d damage, After: %d HP, Actual loss: %d^7", 
                        health, totalBleedingDamage, 10, healthAfter, health - healthAfter))
                    print(string.format("^6[HEALTH DEBUG] Player dead after damage: %s^7", tostring(IsEntityDead(cache.ped))))
                end
                -- Clear flag after a short delay to allow wound detection to resume
                CreateThread(function()
                    Wait(2000) -- 2 second delay (increased from 1 second)
                    ApplyingMedicalDamage = false
                    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                        print("^5[MEDICAL DAMAGE] Flag cleared - wound detection resumed^7")
                    end
                end)
                
                -- Single notification for all bleeding wounds
                if #bleedingWounds > 1 then
                    lib.notify({
                        title = locale('qc_health'),
                        description = string.format(locale('cl_desc_fmt_wound_multiple_bleeding'), totalBleedingDamage),
                        type = 'error',
                        duration = 5000
                    })
                elseif #bleedingWounds == 1 then
                    local wound = bleedingWounds[1]
                    local bodyPartConfig = Config.BodyParts[wound.bodyPart]
                    if bodyPartConfig then
                        lib.notify({
                            title = locale('qc_health'),
                            description = string.format(locale('cl_desc_fmt_wound_bleeding_weakening'),
                                bodyPartConfig.label:lower()),
                            type = 'error',
                            duration = 4000
                        })
                    end
                end
                
                -- Debug logging
                if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
                    print(string.format("^1[BLEEDING DAMAGE] Total %d damage from %d wounds [Time: %d] [Thread: %d]^7", 
                        totalBleedingDamage, #bleedingWounds, GetGameTimer(), threadId))
                    for _, wound in pairs(bleedingWounds) do
                        print(string.format("^1  - %s: level %d = %d damage^7", wound.bodyPart, wound.level, wound.damage))
                    end
                end
            end
        end
        
        ::continue_bleeding_loop::
end)

--=========================================================
-- WOUND PROGRESSION LOOP (Configurable intervals)
--=========================================================
CreateThread(function()
    while true do
        -- Use the shortest interval from config for the main loop (convert minutes to milliseconds)
        -- Individual functions handle their own timing
        local minInterval = math.min(
            (Config.WoundProgression.bandageHealingInterval or 1) * 60000,
            (Config.WoundProgression.bleedingProgressionInterval or 2) * 60000,
            (Config.WoundProgression.painProgressionInterval or 3) * 60000,
            (Config.WoundProgression.painNaturalHealingInterval or 5) * 60000
        )
        
        Wait(minInterval)
        
        if not IsEntityDead(PlayerPedId()) then
            ProcessMovementEffects()
            CheckAndConvertToScars()
        end
    end
end)

--=========================================================
-- UNIFIED MEDICAL PROGRESSION TIMER
--=========================================================
-- Handles bandage decay, infection progression, and wound progression
-- Uses Config.InfectionSystem.progressionInterval (2 minutes) for efficiency
CreateThread(function()
    -- Wait for player to be logged in
    repeat Wait(1000) until LocalPlayer.state['isLoggedIn']
    
    if Config.WoundSystem.debugging.enabled then
        -- Unified progression system started
    end
    
    while true do
        Wait(Config.InfectionSystem.progressionInterval or 120000) -- 2 minutes default
        
        if not IsEntityDead(PlayerPedId()) then
            ProcessUnifiedMedicalProgression()
        end
    end
end)

--=========================================================
-- EXPORTS FOR OTHER MODULES
--=========================================================
exports('GetPlayerWounds', function()
    return PlayerWounds
end)

-- Initialize shared module with wound data
CreateThread(function()
    Wait(50) -- Load first since other modules depend on this
    -- No functions to register, just sync data reference
    -- PlayerWounds is already a global variable accessible by shared module
end)

exports('GetBleedingLevel', function()  
    return BleedingLevel
end)

exports('GetPlayerScars', function()
    local scars = {}
    for bodyPart, wound in pairs(PlayerWounds) do
        if wound.isScar then
            scars[bodyPart] = {
                scarTime = wound.scarTime,
                originalWound = wound.metadata and wound.metadata.description or "unknown injury",
                weaponType = wound.weaponData,
                timestamp = wound.timestamp
            }
        end
    end
    return scars
end)


exports('AddWound', function(bodyPart, painLevel, bleedingLevel, weaponType)
    local artificialData = {
        pain = painLevel,
        bleeding = bleedingLevel,
        chance = 1.0,
        data = weaponType or "Unknown"
    }
    CreateWound(bodyPart, artificialData, 0, nil)
end)

exports('RemoveWound', function(bodyPart)
    if PlayerWounds[bodyPart] then
        PlayerWounds[bodyPart] = nil
        UpdateGlobalBleeding()
        TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', PlayerWounds)
    end
end)

exports('ClearAllWounds', function()
    PlayerWounds = {}
    BleedingLevel = 0
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', PlayerWounds)
end)

exports('ApplyMedicalDamage', function(damage, source)
    -- Safe way for other medical systems to apply damage without triggering wound detection
    local ped = PlayerPedId()
    local currentHealth = GetEntityHealth(ped)
    
    ApplyingMedicalDamage = true
    
    -- Use SetEntityHealth instead of ApplyDamageToPed to avoid multipliers
    local newHealth = math.max(currentHealth - damage, 0)
    SetEntityHealth(ped, newHealth)
    
    if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
        print(string.format("^6[MEDICAL DAMAGE] Applied %d damage from %s (Health: %d -> %d)^7", 
            damage, source or "medical system", currentHealth, newHealth))
    end
    
    -- Clear flag after delay
    CreateThread(function()
        Wait(1000)
        ApplyingMedicalDamage = false
    end)
end)

--=========================================================
-- NETWORK EVENTS
--=========================================================
RegisterNetEvent('QC-AdvancedMedic:client:SyncWoundData')
AddEventHandler('QC-AdvancedMedic:client:SyncWoundData', function(woundData)
    PlayerWounds = woundData or {}
    UpdateGlobalBleeding()
end)

RegisterNetEvent('QC-AdvancedMedic:client:UseMorphine')
AddEventHandler('QC-AdvancedMedic:client:UseMorphine', function(duration)
    LimbEffects.onMorphine = duration or 300 -- 5 minutes default
    lib.notify({
        title = locale('qc_health'),
        description = locale('qc_temporaryWound'),
        type = 'success'
    })
end)

RegisterNetEvent('QC-AdvancedMedic:client:ResetLimbs')
AddEventHandler('QC-AdvancedMedic:client:ResetLimbs', function()
    PlayerWounds = {}
    BleedingLevel = 0
    LimbEffects = {
        movementPenalty = 0.0,
        onMorphine = 0,
        wasOnMorphine = false,
        legCount = 0,
        armCount = 0,
        headCount = 0
    }
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', PlayerWounds)
    
    lib.notify({
        title = locale('qc_health'),
        description = locale('wound_all_healed'),
        type = 'success'
    })
end)

RegisterNetEvent('QC-AdvancedMedic:client:ClearAllWounds')
AddEventHandler('QC-AdvancedMedic:client:ClearAllWounds', function()
    PlayerWounds = {}
    BleedingLevel = 0
    LimbEffects = {
        movementPenalty = 0.0,
        onMorphine = 0,
        wasOnMorphine = false,
        legCount = 0,
        armCount = 0,
        headCount = 0
    }
    
    -- Also clear fractures from envanim_system
    if PlayerFractures then
        PlayerFractures = {}
    end
    
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', PlayerWounds)
end)

RegisterNetEvent('QC-AdvancedMedic:client:LoadWounds')
AddEventHandler('QC-AdvancedMedic:client:LoadWounds', function(woundData)
    if woundData and type(woundData) == 'table' then
        PlayerWounds = woundData
        UpdateGlobalBleeding()
        
        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
            local woundCount = 0
            local woundList = {}
            for bodyPart, wound in pairs(PlayerWounds) do
                woundCount = woundCount + 1
                table.insert(woundList, string.format("%s(P:^3%.1f^6,B:^3%.1f^6)", 
                    bodyPart, tonumber(wound.painLevel) or 0, tonumber(wound.bleedingLevel) or 0))
            end
            print(string.format("^3[^1WOUNDS^3] Loaded ^6%d^3 wounds from database^7", woundCount))
            if woundCount > 0 then
                print(string.format("^3[^1WOUND LOAD^3] ^6%s^7", table.concat(woundList, "^7, ^6")))
            end
        end
    end
end)

--=========================================================
-- SURGICAL BULLET REMOVAL SYSTEM
--=========================================================
-- Handles the bleeding increase when lodged bullets are surgically removed
-- Shot-through wounds: Full bleeding immediately
-- Lodged bullets: Reduced bleeding initially, increases to full when removed

local function RemoveLodgedBullet(bodyPart)
    local wound = PlayerWounds[bodyPart]
    if not wound then
        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
            print(string.format("^1[BULLET REMOVAL ERROR] No wound found on %s^7", bodyPart))
        end
        return false
    end
    
    -- Check if wound has lodged bullet
    if not wound.metadata or not wound.metadata.penetration or wound.metadata.penetration.status ~= "stuck" then
        local bodyPartConfig = Config.BodyParts[bodyPart]
        lib.notify({
            title = locale('cl_menu_surgical_error'),
            description = string.format(locale('cl_desc_fmt_wound_no_bullet'), bodyPartConfig and bodyPartConfig.label or bodyPart),
            type = 'error',
            duration = 5000
        })
        return false
    end
    
    -- Get original weapon data to determine full bleeding amount
    local weaponData = nil
    local weaponHash = wound.weaponHash
    if weaponHash then
        weaponData = GetWeaponDamageData(weaponHash)
    end
    
    if not weaponData then
        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
            print(string.format("^3[BULLET REMOVAL] No weapon data found for %s wound, using current bleeding level^7", bodyPart))
        end
        -- Fallback: increase current bleeding by 60% (since lodged was 40% of original)
        local currentBleeding = wound.bleedingLevel or 1
        wound.bleedingLevel = math.min(math.ceil(currentBleeding / 0.4), 10)
    else
        -- Increase bleeding to full weapon config amount
        wound.bleedingLevel = math.min(weaponData.bleeding or 3, 10)
        
        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
            print(string.format("^3[BULLET REMOVAL] Increased %s bleeding to full amount: %d^7", 
                bodyPart, wound.bleedingLevel))
        end
    end
    
    -- Update wound status - bullet is no longer lodged
    if wound.metadata and wound.metadata.penetration then
        wound.metadata.penetration.status = "removed"
        wound.metadata.penetration.requiresSurgery = false
        
        -- Update wound description
        local penetrationData = wound.metadata.penetration
        local newDescription = GetWoundDescription(wound.weaponType or "unknown", wound.painLevel, penetrationData)
        wound.metadata.description = newDescription
        
        if Config.WoundSystem and Config.WoundSystem.debugging and Config.WoundSystem.debugging.enabled then
            print(string.format("^2[BULLET REMOVAL] Updated wound description: %s^7", newDescription))
        end
    end
    
    -- Update global bleeding level
    UpdateGlobalBleeding()
    
    -- Sync to server
    TriggerServerEvent('QC-AdvancedMedic:server:UpdateWoundData', PlayerWounds)
    
    -- Notify player
    local bodyPartConfig = Config.BodyParts[bodyPart]
    lib.notify({
        title = locale('cl_menu_surgical_procedure'),
        description = string.format(locale('cl_desc_fmt_wound_bullet_removed'),
            bodyPartConfig and bodyPartConfig.label or bodyPart),
        type = 'inform',
        duration = 8000
    })
    
    return true
end

-- Export the bullet removal function for use by medical profession/items
exports('RemoveLodgedBullet', RemoveLodgedBullet)

-- Server event handler for bullet removal (for medic profession use)
RegisterNetEvent('QC-AdvancedMedic:client:RemoveBullet')
AddEventHandler('QC-AdvancedMedic:client:RemoveBullet', function(bodyPart)
    RemoveLodgedBullet(bodyPart)
end)