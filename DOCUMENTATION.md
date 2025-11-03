# Technical Documentation - QC-AdvancedMedic

Complete technical reference for developers and server owners. This guide explains how everything works under the hood, from damage detection to database persistence.

**Version**: 0.2.9-beta
**Platform**: CFX.re (RedM/FiveM)
**Framework**: RSG-Core

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Client-Side Systems](#client-side-systems)
3. [Server-Side Systems](#server-side-systems)
4. [NUI Interface](#nui-interface)
5. [Data Structures](#data-structures)
6. [Events & Exports](#events--exports)
7. [Configuration Reference](#configuration-reference)
8. [Database Schema](#database-schema)
9. [Extending the System](#extending-the-system)
10. [Performance & Optimization](#performance--optimization)

## Architecture Overview

### File Structure

```
QC-AdvancedMedic/
├── fxmanifest.lua              # Resource manifest
├── config.lua                  # Main configuration (1,119 lines)
├── ConfigMissions.lua          # Mission configurations (326 lines)
│
├── client/                     # Client-side logic
│   ├── client_shared.lua       # Shared helpers (IsMedicJob, getters)
│   ├── client.lua              # Core (death, revive, UI triggers)
│   ├── wound_system.lua        # Damage detection & wound creation
│   ├── infection_system.lua    # Infection progression & cure
│   ├── treatment_system.lua    # Treatment application & tracking
│   ├── wound_healing.lua       # Healing timers & scar conversion
│   ├── bag.lua                 # Medical bag mechanics
│   ├── job_system.lua          # Medic job features & missions
│   └── envanim_system.lua      # Environmental & animal damage
│
├── server/                     # Server-side logic
│   ├── server.lua              # Core (item usage, admin commands)
│   ├── database.lua            # Database operations layer
│   ├── medical_events.lua      # Network event handlers
│   ├── medical_server.lua      # /inspect command & profiles
│   ├── sv_bag.lua              # Medical bag server logic
│   └── versionchecker.lua      # Version checking
│
├── ui/build/          # NUI (React compiled)
│   ├── index.html
│   └── static/                 # CSS, JS, media
│
└── locales/                    # Translations (en, es, fr)
```

### System Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. DAMAGE DETECTION (wound_system.lua)                      │
│    - EntityDamaged event → weapon hash lookup               │
│    - Calculate body part from bone hit                      │
│    - Apply pain/bleeding from weapon config                 │
│    - Store in PlayerWounds[bodyPart] table                  │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. PROGRESSION THREADS (wound_system.lua)                   │
│    - Bleeding thread: increases every Config.BleedingProgression │
│    - Pain thread: increases every Config.PainProgression    │
│    - Apply health damage based on bleeding level            │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. TREATMENT APPLICATION (treatment_system.lua)             │
│    - Medic uses /inspect or item directly                   │
│    - Apply treatment → immediate healing + tracking         │
│    - Store in BandageTracker with expiration time           │
│    - Sync to server via TriggerServerEvent                  │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. INFECTION CHECK (infection_system.lua)                   │
│    - Every Config.InfectionTickInterval (2 min)             │
│    - Check bandages past grace period (60s)                 │
│    - Roll infection chance with wound multipliers           │
│    - Progress through 4 stages (25% → 50% → 75% → 90%)     │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. HEALING TO SCARS (wound_healing.lua)                     │
│    - Check conditions: bleeding ≤1, bandaged, time elapsed  │
│    - Track healing progress per body part                   │
│    - Convert wound to scar (isScar = true)                  │
│    - Sync to server → database update                       │
└─────────────────────────────────────────────────────────────┘
```

## Core Systems

### 1. Wound Detection System

**File**: `client/wound_system.lua`

**How It Works**:
1. Listens to `gameEventTriggered` native event for `'CEventNetworkEntityDamage'`
2. Extracts weapon hash from damage event
3. Looks up weapon in `Config.WeaponDamage` table
4. Determines body part from hit bone using `GetPedLastDamageBone()`
5. Calculates pain/bleeding with randomization factor
6. Creates or updates wound in `PlayerWounds` global table

**Key Functions**:

```lua
-- Global data structure
PlayerWounds = {
    ['head'] = {
        pain = 5,
        bleeding = 3,
        health = 85.0,
        weaponUsed = 'WEAPON_REVOLVER_CATTLEMAN',
        description = 'Gunshot wound to head',
        ballisticStatus = 'lodged',
        isScar = false,
        timestamp = 1234567890
    },
    -- ... other body parts
}

-- Damage detection
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local attacker = args[2]
        local weaponHash = args[7]

        -- Process damage
        ProcessDamageEvent(victim, attacker, weaponHash)
    end
end)

-- Body part mapping
function GetBodyPartFromBone(boneId)
    -- Map bone IDs to body parts
    local boneMapping = {
        [31086] = 'head',      -- SKEL_Head
        [14284] = 'spine',     -- SKEL_Spine3
        -- ... etc
    }
    return boneMapping[boneId] or 'upperbody'
end
```

**Ballistics System**:
```lua
-- Distance-based bullet lodging
function CalculateBallisticStatus(weaponType, distance)
    local ranges = Config.BallisticRanges[weaponType]

    if distance < ranges.close then
        return 'pass_through', 0  -- 0% lodging chance
    elseif distance < ranges.medium then
        return 'lodged', 0.05     -- 5% lodging chance
    elseif distance < ranges.long then
        return 'lodged', 0.30     -- 30% lodging chance
    else
        return 'lodged', 0.60     -- 60% lodging chance
    end
end
```

### 2. Treatment System

**File**: `client/treatment_system.lua`

**Treatment Types**:

1. **Bandages** (`ApplyBandage(bodyPart, bandageType)`)
   - Immediate healing: Reduces pain/bleeding by bandage effectiveness
   - Time-based: Continues healing over duration (3-12 minutes)
   - Expiration: 50% symptom return when bandage expires
   - Tracking: Stored in `BandageTracker[bodyPart]`

2. **Tourniquets** (`ApplyTourniquet(bodyPart, tourniquetType)`)
   - Emergency use: Stops bleeding immediately
   - Max duration: 16-30 minutes depending on type
   - Risk: If not removed, causes damage after max duration
   - Limb-specific: Only works on arms/legs

3. **Medicines** (`ApplyMedicine(medicineType)`)
   - System-wide effects (not body part specific)
   - Pain relief, fever reduction, infection resistance
   - Duration: 3-10 minutes with gradual decay

4. **Injections** (`ApplyInjection(injectionType)`)
   - Instant effects: Adrenaline (stamina), morphine (pain), etc.
   - Short duration: 2-10 minutes
   - Potent but risky (addiction potential in RP)

**Application Flow**:
```lua
-- 1. Validate treatment can be applied
function CanApplyTreatment(bodyPart, treatmentType)
    if not PlayerWounds[bodyPart] then return false end
    if PlayerWounds[bodyPart].bleeding == 0 then return false end
    return true
end

-- 2. Apply immediate effects
function ApplyBandage(bodyPart, bandageType)
    local config = Config.Bandages[bandageType]
    local wound = PlayerWounds[bodyPart]

    -- Immediate healing
    wound.bleeding = math.max(0, wound.bleeding - config.immediate_bleeding_reduction)
    wound.pain = math.max(0, wound.pain - config.immediate_pain_reduction)

    -- Track for time-based healing
    BandageTracker[bodyPart] = {
        type = bandageType,
        appliedAt = GetGameTimer(),
        duration = config.duration * 60000,  -- Convert to ms
        effectiveness = config.effectiveness,
        originalWound = {bleeding = wound.bleeding, pain = wound.pain}
    }

    -- Sync to server
    TriggerServerEvent('QC-AdvancedMedic:server:updateTreatment', bodyPart, 'bandage', bandageType)
end

-- 3. Time-based healing thread
CreateThread(function()
    while true do
        Wait(60000)  -- Every 1 minute (Config.BandageHealing)

        for bodyPart, tracker in pairs(BandageTracker) do
            local elapsed = GetGameTimer() - tracker.appliedAt

            if elapsed >= tracker.duration then
                -- Bandage expired - 50% symptom return
                ReturnSymptoms(bodyPart, 0.5)
                BandageTracker[bodyPart] = nil
            else
                -- Continue healing
                HealWound(bodyPart, tracker.effectiveness)
            end
        end
    end
end)
```

### 3. Infection System

**File**: `client/infection_system.lua`

**Infection Stages**:

| Stage | Percentage | Effects | Visual |--|
| 1 | 25% | -5 stamina | Mild discoloration |
| 2 | 50% | -10 stamina, coughing | Swelling |
| 3 | 75% | -20 stamina, -5% speed | Heavy discoloration, fever |
| 4 | 90% | -30 stamina, -15% speed, 2 HP/min damage | Vignette, tremors |

**Infection Logic**:

```lua
-- Global infection data
PlayerInfections = {
    ['head'] = {
        percentage = 35,        -- 0-100
        stage = 2,              -- 1-4
        cureProgress = 0,       -- 0-100
        immunity = false,
        immunityExpires = 0
    }
}

-- Infection progression thread
CreateThread(function()
    while true do
        Wait(Config.InfectionTickInterval * 60000)  -- Every 2 minutes

        for bodyPart, bandage in pairs(BandageTracker) do
            local elapsed = GetGameTimer() - bandage.appliedAt
            local gracePeriod = Config.BandageGracePeriod * 1000  -- 60 seconds

            if elapsed > gracePeriod then
                -- Bandage is "dirty" - roll for infection
                local wound = PlayerWounds[bodyPart]
                local baseChance = Config.InfectionRollChance  -- 15%

                -- Apply wound type multipliers
                local multiplier = 1.0
                if wound.ballisticStatus == 'lodged' then
                    multiplier = 2.0
                elseif wound.ballisticStatus == 'fragmented' then
                    multiplier = 2.5
                end

                local finalChance = baseChance * multiplier
                local roll = math.random(1, 100)

                if roll <= finalChance then
                    -- Infection occurs
                    ProgressInfection(bodyPart, 5)  -- Increase by 5%
                end
            end
        end
    end
end)

-- Cure system
function ApplyCureItem(bodyPart, cureType)
    local config = Config.CureItems[cureType]
    local infection = PlayerInfections[bodyPart]

    if not infection then return end

    -- Increase cure progress
    infection.cureProgress = math.min(100, infection.cureProgress + config.effectiveness)

    -- Reduce infection percentage
    infection.percentage = math.max(0, infection.percentage - (config.effectiveness * 0.5))

    -- If fully cured
    if infection.cureProgress >= 100 then
        infection.percentage = 0
        infection.stage = 0
        infection.immunity = true
        infection.immunityExpires = GetGameTimer() + (config.immunityDuration * 60000)

        TriggerEvent('ox_lib:notify', {
            title = 'Infection Cured',
            description = 'You have temporary immunity',
            type = 'success'
        })
    end
end
```

### 4. Wound Healing to Scars

**File**: `client/wound_healing.lua`

**Healing Conditions**:
1. Bleeding level ≤ 1
2. Active bandage applied
3. Sufficient time elapsed (varies by wound type)
4. No new damage to same body part

**Wound Types & Healing Times**:
```lua
Config.WoundTypes = {
    blunt_trauma = {healTime = 10},     -- 10 minutes
    slash = {healTime = 15},
    stab = {healTime = 20},
    gunshot_through = {healTime = 25},
    bullet_lodged = {healTime = 30},
    bullet_fragmented = {healTime = 40}
}
```

**Healing Process**:

```lua
-- Global healing tracker
HealingProgress = {
    ['head'] = {
        startTime = 1234567890,
        healingTime = 1500000,  -- 25 minutes in ms
        woundData = {...}       -- Original wound
    }
}

-- Check if wound can start healing
function CheckHealingConditions(bodyPart)
    local wound = PlayerWounds[bodyPart]
    local bandage = BandageTracker[bodyPart]

    -- Conditions
    if not wound then return false end
    if wound.isScar then return false end
    if wound.bleeding > 1 then return false end
    if not bandage then return false end

    return true
end

-- Start healing timer
function StartHealing(bodyPart)
    local wound = PlayerWounds[bodyPart]
    local woundType = DetermineWoundType(wound)
    local healTime = Config.WoundTypes[woundType].healTime * 60000  -- To ms

    HealingProgress[bodyPart] = {
        startTime = GetGameTimer(),
        healingTime = healTime,
        woundData = TableDeepCopy(wound)
    }
end

-- Healing check thread
CreateThread(function()
    while true do
        Wait(60000)  -- Check every minute

        for bodyPart, progress in pairs(HealingProgress) do
            local elapsed = GetGameTimer() - progress.startTime

            -- Check if interrupted (new damage)
            if PlayerWounds[bodyPart].timestamp > progress.startTime then
                HealingProgress[bodyPart] = nil
                TriggerEvent('ox_lib:notify', {
                    title = 'Healing Interrupted',
                    description = 'New damage to ' .. bodyPart,
                    type = 'error'
                })
            -- Check if healed
            elseif elapsed >= progress.healingTime then
                ConvertToScar(bodyPart)
                HealingProgress[bodyPart] = nil
            end
        end
    end
end)

-- Convert wound to scar
function ConvertToScar(bodyPart)
    local wound = PlayerWounds[bodyPart]

    wound.isScar = true
    wound.bleeding = 0
    wound.pain = 0
    wound.health = 100.0

    -- Keep metadata for history
    wound.scarTime = os.time()
    wound.originalInjury = wound.description

    -- Sync to server
    TriggerServerEvent('QC-AdvancedMedic:server:convertToScar', bodyPart, wound)

    TriggerEvent('ox_lib:notify', {
        title = 'Wound Healed',
        description = bodyPart .. ' has healed into a scar',
        type = 'success'
    })
end
```

### 5. Medical Inspection System

**File**: `server/medical_server.lua`

**Command**: `/inspect [playerID]`

**Flow**:
1. Medic executes command
2. Server validates medic job via `IsMedicJob()`
3. Server fetches complete medical profile from database
4. Server sends data to medic's client
5. NUI opens with interactive body diagram
6. Medic can examine wounds and apply treatments

**Server-Side**:
```lua
-- Command registration
RSGCore.Commands.Add('inspect', 'Examine patient medical condition', {{name = 'id', help = 'Player ID'}}, true, function(source, args)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    -- Validate medic job
    if not IsMedicJob(Player.PlayerData.job.name) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Access Denied',
            description = 'You are not a medic',
            type = 'error'
        })
        return
    end

    local targetId = tonumber(args[1])
    local Target = RSGCore.Functions.GetPlayer(targetId)

    if not Target then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Player not found',
            type = 'error'
        })
        return
    end

    -- Fetch medical profile from database
    local citizenid = Target.PlayerData.citizenid
    local profile = MySQL.query.await('CALL GetCompleteMedicalProfile(?)', {citizenid})

    -- Send to medic's client
    TriggerClientEvent('QC-AdvancedMedic:client:openInspectionUI', src, {
        targetId = targetId,
        targetName = Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname,
        wounds = profile.wounds,
        treatments = profile.treatments,
        infections = profile.infections,
        history = profile.history
    })
end, 'medic')
```

**Client-Side NUI**:
```lua
-- Open inspection UI
RegisterNetEvent('QC-AdvancedMedic:client:openInspectionUI', function(data)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openInspection',
        data = data
    })
end)

-- NUI callbacks for treatment application
RegisterNUICallback('applyTreatment', function(data, cb)
    local bodyPart = data.bodyPart
    local treatmentType = data.treatmentType
    local targetId = data.targetId

    -- Apply treatment to target player
    TriggerServerEvent('QC-AdvancedMedic:server:medicApplyTreatment', targetId, bodyPart, treatmentType)

    cb('ok')
end)
```

## Data Structures

### PlayerWounds (Client-Side Global)

```lua
PlayerWounds = {
    ['bodyPartName'] = {
        pain = number,              -- 0-10 scale
        bleeding = number,          -- 0-10 scale
        health = number,            -- 0-100 percentage
        weaponUsed = string,        -- Weapon hash or name
        description = string,       -- 'Gunshot wound to head'
        ballisticStatus = string,   -- 'pass_through', 'lodged', 'fragmented'
        isScar = boolean,           -- Is this a healed scar?
        timestamp = number,         -- os.time() when created
        scarTime = number,          -- os.time() when healed (if scar)
        originalInjury = string     -- Description of original injury (if scar)
    }
}
```

### BandageTracker (Client-Side Global)

```lua
BandageTracker = {
    ['bodyPartName'] = {
        type = string,              -- 'cloth', 'cotton', 'linen', 'sterile'
        appliedAt = number,         -- GetGameTimer() timestamp
        duration = number,          -- Duration in milliseconds
        effectiveness = number,     -- 0.0-1.0 healing rate
        originalWound = {           -- Snapshot when bandage applied
            bleeding = number,
            pain = number
        }
    }
}
```

### PlayerInfections (Client-Side Global)

```lua
PlayerInfections = {
    ['bodyPartName'] = {
        percentage = number,        -- 0-100 infection severity
        stage = number,             -- 1-4 infection stage
        cureProgress = number,      -- 0-100 cure progress
        immunity = boolean,         -- Temporary immunity active?
        immunityExpires = number    -- GetGameTimer() timestamp
    }
}
```

## Events & Exports

### Client Events

**Triggerable**:
```lua
-- Update wound data
TriggerEvent('QC-AdvancedMedic:client:updateWound', bodyPart, woundData)

-- Apply treatment
TriggerEvent('QC-AdvancedMedic:client:applyTreatment', bodyPart, treatmentType, treatmentItem)

-- Show wound UI
TriggerEvent('QC-AdvancedMedic:client:showWoundUI')

-- Revive player
TriggerEvent('QC-AdvancedMedic:client:revive')
```

**Registered**:
```lua
-- From server: sync wound data
RegisterNetEvent('QC-AdvancedMedic:client:syncWoundData', function(wounds)
    PlayerWounds = wounds
end)

-- From server: death trigger
RegisterNetEvent('QC-AdvancedMedic:client:onDeath', function()
    -- Handle death state
end)
```

### Server Events

**Triggerable from Client**:
```lua
-- Update wound data in database
TriggerServerEvent('QC-AdvancedMedic:server:updateWoundData', bodyPart, woundData)

-- Apply treatment (medic to patient)
TriggerServerEvent('QC-AdvancedMedic:server:medicApplyTreatment', targetId, bodyPart, treatmentType)

-- Convert wound to scar
TriggerServerEvent('QC-AdvancedMedic:server:convertToScar', bodyPart, woundData)

-- Log medical event
TriggerServerEvent('QC-AdvancedMedic:server:logMedicalEvent', eventType, details)
```

### Exports

**Client Exports**:
```lua
-- Get current wounds
local wounds = exports['QC-AdvancedMedic']:GetPlayerWounds()

-- Get wound for specific body part
local headWound = exports['QC-AdvancedMedic']:GetWound('head')

-- Check if player has any injuries
local hasInjuries = exports['QC-AdvancedMedic']:HasInjuries()

-- Get total bleeding level
local totalBleeding = exports['QC-AdvancedMedic']:GetTotalBleeding()

-- Check if player is medic
local isMedic = exports['QC-AdvancedMedic']:IsMedicJob(jobName)
```

**Server Exports**:
```lua
-- Get player medical profile from database
local profile = exports['QC-AdvancedMedic']:GetMedicalProfile(citizenid)

-- Save wound data
exports['QC-AdvancedMedic']:SaveWoundData(citizenid, bodyPart, woundData)

-- Check if player has medic job
local isMedic = exports['QC-AdvancedMedic']:IsMedicJob(jobName)
```

## Configuration Reference

### Core Settings

```lua
Config.MaxHealth = 600              -- Maximum player health (must match server)
Config.DeathTimer = 300             -- Seconds before forced respawn
Config.UseScreenEffects = true      -- Blood splatter, pain blur effects
Config.DeadMoveCam = true           -- Death camera (true = 360° free-look, false = overhead)
Config.WipeInventoryOnRespawn = false
Config.WipeCashOnRespawn = false
Config.WipeBloodmoneyOnRespawn = false
```

### Wound Progression Timers

```lua
-- All values in MINUTES - Nested under Config.WoundProgression
Config.WoundProgression = {
    bleedingProgressionInterval = 1,     -- How often bleeding increases
    painProgressionInterval = 1,         -- How often pain increases
    painNaturalHealingInterval = 5,      -- Slow natural recovery
    bandageHealingInterval = 1,          -- Accelerated healing with bandage
    bleedingProgressAmount = 0.5,        -- Fixed amount increased per tick
    painProgressAmount = 0.5,            -- Fixed amount increased per tick
    painNaturalHealAmount = 0.5          -- Fixed amount decreased per tick
}

### Fall Damage

```lua
Config.FallDamage = {
    minHeight = 3.0,                    -- Meters for minor injury
    fractureHeight = 8.0,               -- Meters for fracture (non-ragdoll)
    breakHeight = 15.0,                 -- Meters for severe break (non-ragdoll)
    ragdollFractureHeight = 6.0,        -- Lower threshold when ragdolling
    ragdollBreakHeight = 10.0,          -- Lower threshold when ragdolling
    ragdollChance = 20                  -- % chance to ragdoll with leg/foot injuries
}

### Infection System

```lua
Config.InfectionTickInterval = 2            -- Minutes between infection checks
Config.BandageGracePeriod = 60              -- Seconds before bandage decays
Config.InfectionRollChance = 15             -- Base percentage chance
Config.InfectionStageThresholds = {         -- Stage breakpoints
    [1] = 25,
    [2] = 50,
    [3] = 75,
    [4] = 90
}
```

### Weapon Damage Configuration

```lua
Config.WeaponDamage = {
    ['WEAPON_REVOLVER_CATTLEMAN'] = {
        bleedingAmount = 4,                 -- 0-10 scale
        painAmount = 5,                     -- 0-10 scale
        hitChance = 0.8,                    -- 80% to register hit
        canLodge = true,                    -- Can bullet lodge?
        ballisticType = 'handgun',          -- Used for distance calculations
        description = 'Gunshot wound'
    },
    -- ... 100+ more weapons
}
```

### Treatment Configurations

```lua
Config.Bandages = {
    ['cloth'] = {
        label = 'Cloth Bandage',
        duration = 3,                       -- Minutes
        effectiveness = 0.3,                -- 30% healing rate
        immediate_bleeding_reduction = 1,   -- Instant reduction
        immediate_pain_reduction = 1
    },
    -- cotton, linen, sterile...
}

Config.Medicines = {
    ['morphine'] = {
        label = 'Morphine',
        duration = 10,                      -- Minutes
        pain_reduction = 5,                 -- Reduces pain by 5 levels
        side_effects = {'drowsiness'}
    },
    -- laudanum, whiskey, quinine...
}
```

## Database Schema

### Tables

**Note**: The system uses **5 optimized tables** (v0.2.9+) including the new fractures table.

**1. player_wounds**
```sql
CREATE TABLE player_wounds (
    id INT PRIMARY KEY AUTO_INCREMENT,
    citizenid VARCHAR(50) NOT NULL,
    body_part VARCHAR(20) NOT NULL,
    pain INT DEFAULT 0,
    bleeding INT DEFAULT 0,
    health DECIMAL(5,2) DEFAULT 100.00,
    weapon_used VARCHAR(100),
    description TEXT,
    ballistic_status VARCHAR(20),
    is_scar BOOLEAN DEFAULT FALSE,
    scar_time TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_wound (citizenid, body_part)
);
```

**2. medical_treatments**
```sql
CREATE TABLE medical_treatments (
    id INT PRIMARY KEY AUTO_INCREMENT,
    citizenid VARCHAR(50) NOT NULL,
    body_part VARCHAR(20),              -- NULL for system-wide treatments
    treatment_type ENUM('bandage', 'tourniquet', 'medicine', 'injection') NOT NULL,
    item_name VARCHAR(50) NOT NULL,
    applied_by VARCHAR(50),              -- Citizenid of medic (or 'self')
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    INDEX idx_citizen_body (citizenid, body_part)
);
```

**3. player_infections**
```sql
CREATE TABLE player_infections (
    id INT PRIMARY KEY AUTO_INCREMENT,
    citizenid VARCHAR(50) NOT NULL,
    body_part VARCHAR(20) NOT NULL,
    percentage INT DEFAULT 0,
    stage INT DEFAULT 0,
    cure_progress INT DEFAULT 0,
    immunity BOOLEAN DEFAULT FALSE,
    immunity_expires TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_infection (citizenid, body_part)
);
```

**4. player_fractures**
```sql
CREATE TABLE player_fractures (
    id INT PRIMARY KEY AUTO_INCREMENT,
    citizenid VARCHAR(50) NOT NULL,
    body_part VARCHAR(20) NOT NULL,
    fracture_type ENUM('fracture', 'bone_break') NOT NULL,
    severity INT(2) NOT NULL DEFAULT 5,
    pain_level DECIMAL(3,1) NOT NULL DEFAULT 0.0,
    mobility_impact DECIMAL(3,2) NOT NULL DEFAULT 0.0,
    healing_progress DECIMAL(5,2) NOT NULL DEFAULT 0.0,
    requires_surgery BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    healed_at TIMESTAMP NULL,
    UNIQUE KEY unique_fracture (citizenid, body_part)
);
```

**5. medical_history**
```sql
CREATE TABLE medical_history (
    id INT PRIMARY KEY AUTO_INCREMENT,
    citizenid VARCHAR(50) NOT NULL,
    event_type ENUM('wound_created', 'wound_healed', 'treatment_applied',
                    'infection_started', 'infection_cured', 'death',
                    'revived', 'scar_created') NOT NULL,
    body_part VARCHAR(20),
    details JSON,                       -- Flexible data storage
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_citizen_date (citizenid, created_at)
);
```

### Stored Procedures

**GetCompleteMedicalProfile**:
```sql
CREATE PROCEDURE GetCompleteMedicalProfile(IN p_citizenid VARCHAR(50))
BEGIN
    -- Get all wounds (including scars)
    SELECT * FROM player_wounds WHERE citizenid = p_citizenid;

    -- Get active treatments
    SELECT * FROM medical_treatments
    WHERE citizenid = p_citizenid AND expires_at > NOW();

    -- Get infections
    SELECT * FROM player_infections WHERE citizenid = p_citizenid;

    -- Get recent medical history (last 30 days)
    SELECT * FROM medical_history
    WHERE citizenid = p_citizenid AND created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)
    ORDER BY created_at DESC
    LIMIT 50;
END
```

**CleanupExpiredMedicalData**:
```sql
CREATE PROCEDURE CleanupExpiredMedicalData()
BEGIN
    -- Remove expired treatments
    DELETE FROM medical_treatments WHERE expires_at < NOW();

    -- Archive old medical history (older than 30 days)
    DELETE FROM medical_history WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY);

    -- Remove cured infections
    DELETE FROM player_infections WHERE percentage = 0 AND immunity = FALSE;
END
```

## Extending the System

### Adding New Weapons

1. Open `config.lua`
2. Find `Config.WeaponDamage` section (line ~337)
3. Add your weapon:

```lua
['WEAPON_YOUR_GUN'] = {
    bleedingAmount = 5,
    painAmount = 6,
    hitChance = 0.9,
    canLodge = true,
    ballisticType = 'rifle',
    description = 'High-powered rifle wound'
},
```

4. No code changes needed - system reads config on startup

### Adding New Treatment Items

1. **Add to `config.lua`**:
```lua
Config.Bandages['super_bandage'] = {
    label = 'Super Bandage',
    duration = 15,              -- 15 minutes
    effectiveness = 0.8,        -- 80% healing rate
    immediate_bleeding_reduction = 3,
    immediate_pain_reduction = 2
}
```

2. **Add item to `rsg-core/shared/items.lua`**:
```lua
['super_bandage'] = {
    ['name'] = 'super_bandage',
    ['label'] = 'Super Bandage',
    ['weight'] = 150,
    ['type'] = 'item',
    ['image'] = 'super_bandage.png',
    ['unique'] = false,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['description'] = 'Advanced medical bandage'
},
```

3. **Register useable item in `server/server.lua`**:
```lua
RSGCore.Functions.CreateUseableItem('super_bandage', function(source, item)
    local src = source
    TriggerClientEvent('QC-AdvancedMedic:client:useBandage', src, 'super_bandage')
end)
```

### Creating Custom Wound Types

1. **Define in `config.lua`**:
```lua
Config.WoundTypes.custom_burn = {
    healTime = 35,              -- 35 minutes to heal
    scarType = 'burn_scar',
    description = 'Severe burn injury'
}
```

2. **Modify `wound_system.lua`** to assign wound type:
```lua
function DetermineWoundType(wound)
    -- Your custom logic
    if wound.weaponUsed == 'WEAPON_MOLOTOV' then
        return 'custom_burn'
    end

    -- Existing logic
    if wound.ballisticStatus == 'fragmented' then
        return 'bullet_fragmented'
    end
    -- ...
end
```

### Adding New Body Parts

1. **Add to `Config.BodyParts`** in `config.lua`:
```lua
['custom_part'] = {
    label = 'Custom Body Part',
    maxHealth = 100,
    canLimp = false,
    bones = {12345}             -- Bone ID from game
}
```

2. **Update NUI** to display new body part:
   - Add PNG image: `ui/build/static/media/custom_part.png`
   - Update React component to include clickable region

3. **Update bone mapping** in `wound_system.lua`:
```lua
local boneMapping = {
    [12345] = 'custom_part',
    -- ... existing bones
}
```

### Creating Custom Events

**Trigger custom medical event**:
```lua
-- Client-side
TriggerServerEvent('QC-AdvancedMedic:server:logMedicalEvent', 'custom_event', {
    bodyPart = 'head',
    severity = 'high',
    customData = 'Additional info'
})

-- Server-side (in medical_events.lua)
RegisterNetEvent('QC-AdvancedMedic:server:logMedicalEvent', function(eventType, details)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    MySQL.insert('INSERT INTO medical_history (citizenid, event_type, details) VALUES (?, ?, ?)', {
        Player.PlayerData.citizenid,
        eventType,
        json.encode(details)
    })
end)
```

## Performance Optimization

### Thread Management

**Wound Progression Thread**:
```lua
-- Runs every Config.BleedingProgression minutes
-- Impact: ~0.01ms per tick
CreateThread(function()
    while true do
        Wait(Config.BleedingProgression * 60000)

        for bodyPart, wound in pairs(PlayerWounds) do
            if not wound.isScar and wound.bleeding > 0 then
                ProgressBleeding(bodyPart)
            end
        end
    end
end)
```

**Optimization Tips**:
1. Increase tick intervals for lower server loads
2. Use `Wait(0)` sparingly - prefer longer intervals
3. Break long loops across multiple frames
4. Cache frequently accessed config values

### Database Optimization

**Use Stored Procedures**:
```lua
-- Instead of multiple queries:
-- ❌ BAD
local wounds = MySQL.query.await('SELECT * FROM player_wounds WHERE citizenid = ?', {citizenid})
local treatments = MySQL.query.await('SELECT * FROM medical_treatments WHERE citizenid = ?', {citizenid})
local infections = MySQL.query.await('SELECT * FROM player_infections WHERE citizenid = ?', {citizenid})

-- ✅ GOOD - Single stored procedure call
local profile = MySQL.query.await('CALL GetCompleteMedicalProfile(?)', {citizenid})
```

**Batch Updates**:
```lua
-- ❌ BAD - Multiple individual updates
for bodyPart, wound in pairs(PlayerWounds) do
    MySQL.update('UPDATE player_wounds SET bleeding = ? WHERE citizenid = ? AND body_part = ?', {
        wound.bleeding, citizenid, bodyPart
    })
end

-- ✅ GOOD - Single batch update
MySQL.transaction({
    {query = 'UPDATE player_wounds SET bleeding = ? WHERE citizenid = ? AND body_part = ?', values = {...}},
    {query = 'UPDATE player_wounds SET bleeding = ? WHERE citizenid = ? AND body_part = ?', values = {...}},
    -- ...
})
```

## Troubleshooting for Developers

### Debugging Wound Detection

```lua
-- In client/wound_system.lua, add debug prints:
RegisterNetEvent('gameEventTriggered', function(name, args)
    if Config.Debug then
        print('^3[DEBUG] Event:', name)
        print('^3[DEBUG] Weapon Hash:', args[7])
        print('^3[DEBUG] Damage:', args[3])
    end
end)
```

### Checking Database Connections

```lua
-- In server/database.lua:
function TestDatabaseConnection()
    local result = MySQL.query.await('SELECT 1 as test')
    if result and result[1] and result[1].test == 1 then
        print('^2[QC-AdvancedMedic] Database connected successfully^7')
        return true
    else
        print('^1[QC-AdvancedMedic] Database connection failed^7')
        return false
    end
end

-- Call on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        TestDatabaseConnection()
    end
end)
```

### NUI Debugging

Open browser console (F8 → Console tab) and add logging:

```javascript
// In NUI JavaScript
window.addEventListener('message', function(event) {
    console.log('[NUI] Received message:', event.data);

    if (event.data.action === 'openInspection') {
        console.log('[NUI] Opening inspection with data:', event.data.data);
    }
});
```

**Questions or need help extending the system?**
- GitHub Issues: [Link]
- Discord: [Link]
- Documentation updates welcome via PR
