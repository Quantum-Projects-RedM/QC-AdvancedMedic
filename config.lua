--=========================================================
--                QC-ADVANCED MEDIC CONFIGURATION
--=========================================================
-- IMPORTANT: This is a production-ready configuration file
-- Please read the documentation before making changes
-- Support: 
--=========================================================

Config = {}

--=========================================================
-- CORE SETTINGS
--=========================================================

-- Debug mode (DISABLE for production)
Config.Debug = false

-- Language/Locale Settings  
Config.Locale = 'en'

--=========================================================
-- DEBUGGING CONFIGURATION
--=========================================================
Config.WoundSystem = {
    debugging = {
        enabled = true,  -- Enable wound system debugging (set to false for production)
        printDamageDetection = true,
        printWoundCreation = true,
        printBodyPartMapping = true
    }
}

-- UNIFIED MEDICAL TICK SYSTEM INFO:
-- All medical progression (injury healing, bleeding, infections, bandages) 
-- now runs on one efficient timer every 2 minutes by default.
-- Damage detection remains separate for instant responsiveness.
-- Adjust MEDICAL_TICK_INTERVAL below to customize timing (in milliseconds)

-- Core System Settings
Config.MaxHealth = 600                          -- Maximum player health
Config.DeathTimer = 300                         -- Death timer in seconds (5 minutes)
Config.UseScreenEffects = true                  -- Enable bleeding/injury screen effects

-- Inventory Integration
Config.ImagePath = 'rsg-inventory/html/images/' -- Image path for inventory icons
Config.Image = "rsg-inventory/html/images/"     -- Alternative image path

-- Death Camera Settings
Config.DeadMoveCam = true  -- true = 360° free-look camera (WARNING: High performance impact ~0.10-0.14ms)
                           -- false = Simple overhead camera (Recommended - Low performance ~0.01-0.02ms)

-- Respawn Settings
Config.WipeInventoryOnRespawn = false           -- Wipe inventory on death
Config.WipeCashOnRespawn = false               -- Wipe cash on death  
Config.WipeBloodmoneyOnRespawn = false         -- Wipe blood money on death

--=========================================================
-- MEDIC JOB SETTINGS
--=========================================================

-- Medic jobs are defined in Config.MedicJobLocations table below
-- Config.JobRequired is no longer used - system uses Config.MedicJobLocations instead

-- Medic Action Timings (in milliseconds)
Config.MedicReviveTime = 8000                  -- Time for medic to revive player
Config.MedicTreatTime = 6000                   -- Time for medic to treat wounds
Config.BandageTime = 10000                     -- Time to apply bandage

-- Medic System Settings
Config.MedicCallDelay = 60                     -- Delay between medic calls (seconds)
Config.AddGPSRoute = true                      -- Add GPS route to medic calls
Config.ResetOutlawStatus = false               -- Reset outlaw status on medic treatment
Config.EnableMedicMissions = true             -- Enable random medic missions

-- Health Restoration
Config.BandageHealthRestore = 25               -- Health restored by bandage
Config.BandageHealth = 50                      -- Additional health restoration

-- Scar/Past Injury System
Config.MaxSavedInjuries = 5                   -- Maximum number of past injuries/scars to keep per player
Config.EnableScarSystem = true                -- Enable scar/past injury tracking

--=========================================================
-- INJURY SYSTEM SETTINGS
--=========================================================

-- Height-Based Fall Damage Configuration
Config.FallDamage = {
    minHeight = 3.0,                          -- Minimum height (meters) to cause injury
    fractureHeight = 8.0,                     -- Non-ragdoll: fractures start here
    breakHeight = 15.0,                       -- Non-ragdoll: breaks start here
    ragdollFractureHeight = 6.0,              -- Ragdoll: fractures start here (lower)
    ragdollBreakHeight = 10.0,                -- Ragdoll: breaks start here (lower)
    ragdollChance = 20                        -- Chance (%) to randomly ragdoll when moving with leg/foot fractures/breaks
}

--=========================================================
-- WOUND PROGRESSION & HEALING TIMERS (All values in MINUTES)
--=========================================================
Config.WoundProgression = {
    
    -- SERVER-SIDE REALISTIC TIME-BASED PROGRESSION (No RNG)
    -- All intervals in MINUTES - server authoritative for anti-cheat
    
    -- Wound progression (guaranteed if conditions met - no chance involved)
    bleedingProgressionInterval = 1,           -- 1 minute - bleeding ALWAYS increases if: bleeding > 0 AND not bandaged
    painProgressionInterval = 1,               -- 1 minute - pain ALWAYS increases if: bleeding > 0 AND not bandaged (only bleeding wounds get more painful)
    
    -- Natural healing (guaranteed if conditions met)
    painNaturalHealingInterval = 5,            -- 5 minutes - pain ALWAYS decreases if: bleeding = 0 AND not bandaged
    
    -- Bandage healing (guaranteed - handled separately in treatment system)
    bandageHealingInterval = 1,                -- 1 minute - how often bandages reduce bleeding/pain
    
    -- Progression amounts (fixed amounts, no randomness)
    bleedingProgressAmount = 0.5,              -- Fixed bleeding increase per interval
    painProgressAmount = 0.5,                  -- Fixed pain increase per interval  
    painNaturalHealAmount = 0.5,               -- Fixed pain decrease per natural healing
}

--=========================================================
-- Storage & Bag Limits
--=========================================================

Config.Storage = {
    MaxWeight = 4000000,
    MaxSlots  = 48
}

Config.Bag = {
    MaxWeight = 1000000,
    MaxSlots  = 10
}

--=========================================================
-- Medic Crafting
--=========================================================

Config.MedicBagCrafting = {
    {
        category    = 'First Aid',
        crafttime   = 30000,
        craftingrep = 0,
        ingredients = {
            { item = 'apple', amount = 1 },
        },
        receive     = 'cotton_band',
        giveamount  = 1
    },
}

--=========================================================
-- Medic Job & Respawn Locations
--=========================================================
Config.Blip = {
    Name   = 'Medic',
    Sprite = 'blip_shop_doctor',
    Scale  = 0.2
}

Config.MedicJobLocations = {
    { -- Valentine
        name = 'Valentine Medic',
        prompt = 'valmedic',
        coords = vector3(-289.46, 806.82, 119.39 - 0.08),
        showblip = true,
        job = 'valmedic'
    },
    {
        name = 'Saint Denis',
        prompt = 'sdmedic',
        coords = vector3(0.0, 0.0, 0.0 - 0.08),
        showblip = true,
        job = 'sdmedic'
    }
}

-- Respawn Locations
Config.RespawnLocations =
{
    [1] = {coords = vector4(-242.69, 796.27, 121.16, 110.18)}, -- Valentine
    [2] = {coords = vector4(-733.28, -1242.97, 44.73, 87.64)}, -- Blackwater
    [3] = {coords = vector4(-1801.98, -366.95, 161.66, 236.04)}, -- Strawberry
    [4] = {coords = vector4(-3613.85, -2640.1, -11.73, 47.92)}, -- Armadillo
    [5] = {coords = vector4(-5436.5, -2930.96, 0.69, 182.25)}, -- Tumbleweed
    [6] = {coords = vector4(2725.33, -1067.42, 47.4, 168.42)}, -- Staint Denis
    [7] = {coords = vector4(1291.85, -1236.22, 80.93, 210.67)}, -- Rhodes
    [8] = {coords = vector4(3033.01, 433.82, 63.81, 65.9)}, -- Van Horn
    [9] = {coords = vector4(3016.71, 1345.64, 42.69, 67.85)}, -- Annesburg
   -- [10] = {coords = vector4(1184.1661, 2035.0424, 323.9266)} -- Vestica Aryn
}

--=========================================================
-- INJURY & TREATMENT DESCRIPTIONS (Unified System)
--=========================================================

-- Pain/Injury severity system - EXACTLY 10 levels (1-10 scale)
-- IMPORTANT FOR CUSTOMERS: Pain levels correspond to weapon damage and progression
-- Level 1-3: Minor injuries (environmental damage, small cuts)
-- Level 4-6: Moderate injuries (pistol shots, knife wounds) 
-- Level 7-10: Severe injuries (rifles, shotguns, critical damage)
Config.InjuryStates = {
    [1] = { 
        pain = 'slight soreness', 
        bleeding = 'minor bleeding', 
        urgency = 'very low',
        treatment = 'Rest or apply salve',
        painDesc = 'Rest and basic comfort measures',
        bleedDesc = 'Apply light pressure or basic bandage',
        unifiedDesc = 'Rest and apply light bandage for comfort',
        painDamagePerTick = 1.5,        -- FIXED: Low pain damage per tick (2 min intervals)
        bleedingDamagePerTick = 3.0     -- FIXED: Low bleeding damage per tick
    },
    [2] = { 
        pain = 'mild discomfort', 
        bleeding = 'light bleeding', 
        urgency = 'low',
        treatment = 'Apply salve or liniment',
        painDesc = 'Apply liniment or mild pain relief',
        bleedDesc = 'Clean wound and apply basic bandage',
        unifiedDesc = 'Apply liniment and bandage for comfort and healing',
        painDamagePerTick = 1.5,
        bleedingDamagePerTick = 5.0
    },
    [3] = { 
        pain = 'noticeable ache', 
        bleeding = 'moderate bleeding', 
        urgency = 'low',
        treatment = 'Use basic bandage or poultice',
        painDesc = 'Use poultice or mild pain tonic',
        bleedDesc = 'Apply firm bandage to control bleeding',
        unifiedDesc = 'Use poultice and firm bandage for pain relief and bleeding control',
        painDamagePerTick = 2.5,
        bleedingDamagePerTick = 7.0
    },
    [4] = { 
        pain = 'persistent pain', 
        bleeding = 'steady bleeding', 
        urgency = 'medium',
        treatment = 'Apply bandage and pain tonic',
        painDesc = 'Apply pain tonic or laudanum for relief',
        bleedDesc = 'Apply pressure bandage to stop bleeding',
        unifiedDesc = 'Apply pressure bandage and pain tonic for comprehensive treatment',
        painDamagePerTick = 3.0,
        bleedingDamagePerTick = 10.0
    },
    [5] = { 
        pain = 'sharp pain', 
        bleeding = 'significant bleeding', 
        urgency = 'medium',
        treatment = 'Bandage immediately, consider medical attention',
        painDesc = 'Strong pain medication recommended - laudanum or morphine',
        bleedDesc = 'Multiple bandages needed to control significant bleeding',
        unifiedDesc = 'Immediate bandaging and strong pain medication required',
        painDamagePerTick = 4.5,
        bleedingDamagePerTick = 14.0
    },
    [6] = { 
        pain = 'intense throbbing', 
        bleeding = 'heavy bleeding', 
        urgency = 'high',
        treatment = 'Emergency bandaging and pain relief required',
        painDesc = 'Emergency pain management - morphine injection required',
        bleedDesc = 'Apply tourniquet or multiple pressure bandages immediately',
        unifiedDesc = 'EMERGENCY: Tourniquet application and morphine injection required',
        painDamagePerTick = 6.0,
        bleedingDamagePerTick = 16.0
    },
    [7] = { 
        pain = 'severe agony', 
        bleeding = 'severe bleeding', 
        urgency = 'high',
        treatment = 'Immediate medical intervention needed',
        painDesc = 'CRITICAL: High-dose morphine and medical supervision required',
        bleedDesc = 'CRITICAL: Emergency tourniquet and immediate surgical intervention',
        unifiedDesc = 'LIFE-THREATENING: Emergency surgery and intensive pain management required',
        painDamagePerTick = 8.0,
        bleedingDamagePerTick = 18.0
    },
    [8] = { 
        pain = 'excruciating pain', 
        bleeding = 'critical bleeding', 
        urgency = 'critical',
        treatment = 'Life-threatening - urgent medical care',
        painDesc = 'URGENT: Maximum morphine dosage and immediate sedation required',
        bleedDesc = 'URGENT: Arterial compression and emergency blood transfusion needed',
        unifiedDesc = 'CRITICAL EMERGENCY: Life-saving intervention required immediately',
        painDamagePerTick = 10.0,
        bleedingDamagePerTick = 22.0
    },
    [9] = { 
        pain = 'overwhelming agony', 
        bleeding = 'massive bleeding', 
        urgency = 'critical',
        treatment = 'Emergency medical attention - near death',
        painDesc = 'FATAL: Patient near unconsciousness from pain - emergency sedation',
        bleedDesc = 'FATAL: Massive blood loss - emergency transfusion and surgical repair',
        unifiedDesc = 'IMMINENT DEATH: Emergency resuscitation and trauma surgery required',
        painDamagePerTick = 12.0,
        bleedingDamagePerTick = 26.0
    },
    [10] = { 
        pain = 'unbearable torture', 
        bleeding = 'arterial bleeding', 
        urgency = 'fatal',
        treatment = 'Immediate life-saving intervention required',
        painDesc = 'DEATH IMMINENT: Patient unconscious from shock - emergency intervention',
        bleedDesc = 'DEATH IMMINENT: Arterial rupture - emergency surgery or death within minutes',
        unifiedDesc = 'CERTAIN DEATH: Immediate trauma surgery and resuscitation required to prevent death',
        painDamagePerTick = 14.0,        -- FIXED: Maximum pain damage
        bleedingDamagePerTick = 35.0    -- FIXED: Maximum bleeding damage (deadly)
    }
}
--========================================================
-- Body Part Definitions (Production Ready)
--=========================================================
Config.BodyParts = {
    HEAD       = { label = 'Head',       maxHealth = 100 , limp = false },
    NECK       = { label = 'Neck',       maxHealth = 80 , limp = false  },
    SPINE      = { label = 'Spine',      maxHealth = 120 , limp = true },
    UPPER_BODY = { label = 'Upper Body', maxHealth = 150 , limp = false },
    LOWER_BODY = { label = 'Lower Body', maxHealth = 150 , limp = true },
    LARM       = { label = 'Left Arm',   maxHealth = 90 , limp = false  },
    LHAND      = { label = 'Left Hand',  maxHealth = 60 , limp = false  },
    LFINGER    = { label = 'Left Fingers', maxHealth = 40 , limp = false },
    LLEG       = { label = 'Left Leg',   maxHealth = 110 , limp = true },
    LFOOT      = { label = 'Left Foot',  maxHealth = 70 , limp = true  },
    RARM       = { label = 'Right Arm',  maxHealth = 90 , limp = false  },
    RHAND      = { label = 'Right Hand', maxHealth = 60 , limp = false  },
    RFINGER    = { label = 'Right Fingers', maxHealth = 40 , limp = false },
    RLEG       = { label = 'Right Leg',  maxHealth = 110 , limp = true },
    RFOOT      = { label = 'Right Foot', maxHealth = 70 , limp = true  },
}


--=========================================================
-- PRODUCTION WEAPON DAMAGE SYSTEM
--=========================================================
-- Realistic bleeding chances with dynamic pain calculation
-- bleeding: Amount of bleeding on hit (if chance succeeds)
-- chance: Probability of bleeding occurring (0.0 = never, 1.0 = always)
-- pain: Calculated dynamically as bleeding + 1 (tissue damage)
-- data: Weapon category for medical treatment decisions

Config.WeaponDamage = {
    --=========================================================
    -- PISTOLS & SMALL REVOLVERS (Pain calculated as bleeding + 1)
    --=========================================================
    [GetHashKey("WEAPON_PISTOL_MAUSER")] = { bleeding = 1, chance = 0.3, data = ".32 ACP", ballisticType = "pistol", status = "bullet" },
    [GetHashKey("WEAPON_PISTOL_MAUSER_DRUNK")] = { bleeding = 1, chance = 0.3, data = ".32 ACP", ballisticType = "pistol", status = "bullet" },
    [GetHashKey("WEAPON_PISTOL_SEMIAUTO")] = { bleeding = 1, chance = 0.35, data = ".32 ACP", ballisticType = "pistol", status = "bullet" },
    [GetHashKey("WEAPON_PISTOL_M1899")] = { bleeding = 1, chance = 0.4, data = ".30 Luger", ballisticType = "pistol", status = "bullet" },
    [GetHashKey("WEAPON_PISTOL_VOLCANIC")] = { bleeding = 1, chance = 0.45, data = ".41 Short", ballisticType = "pistol", status = "bullet" },
    
    --=========================================================
    -- REVOLVERS (Moderate-high pain, good bleeding chance)
    --=========================================================
    [GetHashKey("WEAPON_REVOLVER_CATTLEMAN")] = { bleeding = 2, chance = 0.5, data = ".45 Colt", ballisticType = "revolver", status = "bullet" },
    [GetHashKey("WEAPON_REVOLVER_CATTLEMAN_JOHN")] = { bleeding = 2, chance = 0.5, data = ".45 Colt", ballisticType = "revolver", status = "bullet" },
    [GetHashKey("WEAPON_REVOLVER_CATTLEMAN_MEXICAN")] = { bleeding = 2, chance = 0.5, data = ".45 Colt", ballisticType = "revolver", status = "bullet" },
    [GetHashKey("WEAPON_REVOLVER_CATTLEMAN_PIG")] = { bleeding = 2, chance = 0.5, data = ".45 Colt", ballisticType = "revolver", status = "bullet" },
    [GetHashKey("WEAPON_REVOLVER_SCHOFIELD")] = { bleeding = 2, chance = 0.55, data = ".45 Schofield", ballisticType = "revolver", status = "bullet" },
    [GetHashKey("WEAPON_REVOLVER_LEMAT")] = { bleeding = 2, chance = 0.6, data = ".44 Caliber", ballisticType = "revolver", status = "bullet" },

    --=========================================================
    -- RIFLES & REPEATERS (High bleeding chance - rifle rounds)
    --=========================================================
    [GetHashKey("WEAPON_RIFLE_VARMINT")] = { bleeding = 1, chance = 0.65, data = ".22 Caliber", ballisticType = "rifle", status = "bullet" },
    [GetHashKey("WEAPON_REPEATER_CARBINE")] = { bleeding = 2, chance = 0.75, data = ".44-40 Winchester", ballisticType = "rifle", status = "bullet" },
    [GetHashKey("WEAPON_REPEATER_CARBINE_SADIE")] = { bleeding = 2, chance = 0.75, data = ".44-40 Winchester", ballisticType = "rifle", status = "bullet" },
    [GetHashKey("WEAPON_REPEATER_WINCHESTER")] = { bleeding = 2, chance = 0.8, data = ".44-40 Winchester", ballisticType = "rifle", status = "bullet" },
    [GetHashKey("WEAPON_REPEATER_WINCHESTER_JOHN")] = { bleeding = 2, chance = 0.8, data = ".44-40 Winchester", ballisticType = "rifle", status = "bullet" },
    [GetHashKey("WEAPON_REPEATER_EVANS")] = { bleeding = 2, chance = 0.75, data = ".44 Evans", ballisticType = "rifle", status = "bullet" },
    [GetHashKey("WEAPON_RIFLE_SPRINGFIELD")] = { bleeding = 3, chance = 0.85, data = ".45-70 Government", ballisticType = "rifle", status = "bullet" },

    --=========================================================
    -- SNIPER RIFLES (Very high bleeding chance - high velocity)
    --=========================================================
    [GetHashKey("WEAPON_RIFLE_BOLTACTION")] = { bleeding = 4, chance = 0.9, data = ".270 Winchester", ballisticType = "sniper", status = "bullet" },
    [GetHashKey("WEAPON_RIFLE_BOLTACTION_BILL")] = { bleeding = 4, chance = 0.9, data = ".270 Winchester", ballisticType = "sniper", status = "bullet" },
    [GetHashKey("WEAPON_SNIPERRIFLE_CARCANO")] = { bleeding = 4, chance = 0.9, data = "6.5mm Carcano", ballisticType = "sniper", status = "bullet" },
    [GetHashKey("WEAPON_SNIPERRIFLE_ROLLINGBLOCK")] = { bleeding = 4, chance = 0.95, data = ".45-70 Government", ballisticType = "sniper", status = "bullet" },
    [GetHashKey("WEAPON_SNIPERRIFLE_ROLLINGBLOCK_EXOTIC")] = { bleeding = 4, chance = 0.95, data = ".45-70 Government", ballisticType = "sniper", status = "bullet" },
    [GetHashKey("WEAPON_SNIPERRIFLE_ROLLINGBLOCK_LENNY")] = { bleeding = 4, chance = 0.95, data = ".45-70 Government", ballisticType = "sniper", status = "bullet" },
    [GetHashKey("WEAPON_RIFLE_ELEPHANT")] = { bleeding = 5, chance = 0.95, data = ".600 Nitro Express", ballisticType = "sniper", status = "bullet" },

    --=========================================================
    -- SHOTGUNS (Almost always bleed - multiple pellets)
    --=========================================================
    [GetHashKey("WEAPON_SHOTGUN_DOUBLEBARREL")] = { bleeding = 4, chance = 0.9, data = "12 Gauge", ballisticType = "shotgun", status = "pellets" },
    [GetHashKey("WEAPON_SHOTGUN_DOUBLEBARREL_EXOTIC")] = { bleeding = 4, chance = 0.9, data = "12 Gauge", ballisticType = "shotgun", status = "pellets" },
    [GetHashKey("WEAPON_SHOTGUN_DOUBLEBARREL_UNCLE")] = { bleeding = 4, chance = 0.9, data = "12 Gauge", ballisticType = "shotgun", status = "pellets" },
    [GetHashKey("WEAPON_SHOTGUN_PUMP")] = { bleeding = 4, chance = 0.85, data = "12 Gauge", ballisticType = "shotgun", status = "pellets" },
    [GetHashKey("WEAPON_SHOTGUN_REPEATING")] = { bleeding = 4, chance = 0.85, data = "12 Gauge", ballisticType = "shotgun", status = "pellets" },
    [GetHashKey("WEAPON_SHOTGUN_SEMIAUTO")] = { bleeding = 3, chance = 0.85, data = "12 Gauge", ballisticType = "shotgun", status = "pellets" },
    [GetHashKey("WEAPON_SHOTGUN_SEMIAUTO_HOSEA")] = { bleeding = 3, chance = 0.85, data = "12 Gauge", ballisticType = "shotgun", status = "pellets" },
    [GetHashKey("WEAPON_SHOTGUN_SAWEDOFF")] = { bleeding = 4, chance = 0.95, data = "12 Gauge Sawed-Off", ballisticType = "shotgun", status = "pellets" },
    [GetHashKey("WEAPON_SHOTGUN_SAWEDOFF_CHARLES")] = { bleeding = 4, chance = 0.95, data = "12 Gauge Sawed-Off", ballisticType = "shotgun", status = "pellets" },

    --=========================================================
    -- CUTTING WEAPONS (High pain, always bleed - sharp edges)
    --=========================================================
    [GetHashKey("WEAPON_MELEE_KNIFE")] = { bleeding = 3, chance = 0.95, data = "Knife", ballisticType = "melee", status = "deep_cut" },
    [GetHashKey("WEAPON_MELEE_MACHETE")] = { bleeding = 4, chance = 0.95, data = "LargeBlade", ballisticType = "melee", status = "deep_cut" },
    [GetHashKey("WEAPON_MELEE_CLEAVER")] = { bleeding = 4, chance = 0.9, data = "LargeBlade", ballisticType = "melee", status = "deep_cut" },
    [GetHashKey("WEAPON_MELEE_BROKEN_SWORD")] = { bleeding = 3, chance = 0.85, data = "BrokenBlade", ballisticType = "melee", status = "deep_cut" },
    [GetHashKey("WEAPON_THROWN_TOMAHAWK")] = { bleeding = 4, chance = 0.9, data = "Steel Tomahawk", ballisticType = "thrown", status = "embedded_hatchet" },
    
    -- Hatchets/Axes (Heavy cutting tools)
    [GetHashKey("WEAPON_MELEE_HATCHET")] = { bleeding = 4, chance = 0.85, data = "Hatchet", ballisticType = "melee", status = "deep_cut" },
    [GetHashKey("WEAPON_MELEE_HATCHET_HUNTER")] = { bleeding = 4, chance = 0.85, data = "Hatchet", ballisticType = "melee", status = "deep_cut" },
    [GetHashKey("WEAPON_MELEE_HATCHET_HUNTER_RUSTED")] = { bleeding = 4, chance = 0.9, data = "RustedHatchet", ballisticType = "melee", status = "deep_cut" },
    [GetHashKey("WEAPON_MELEE_HATCHET_HEWING")] = { bleeding = 4, chance = 0.9, data = "HeavyHatchet", ballisticType = "melee", status = "deep_cut" },
    [GetHashKey("WEAPON_MELEE_HATCHET_DOUBLE_BIT")] = { bleeding = 5, chance = 0.95, data = "HeavyHatchet", ballisticType = "melee", status = "deep_cut" },
    [GetHashKey("WEAPON_MELEE_HATCHET_DOUBLE_BIT_RUSTED")] = { bleeding = 5, chance = 0.95, data = "RustedHatchet", ballisticType = "melee", status = "deep_cut" },
    [GetHashKey("WEAPON_MELEE_HATCHET_VIKING")] = { bleeding = 4, chance = 0.9, data = "HeavyHatchet", ballisticType = "melee", status = "deep_cut" },
    [GetHashKey("WEAPON_MELEE_ANCIENT_HATCHET")] = { bleeding = 4, chance = 0.85, data = "Hatchet", ballisticType = "melee", status = "deep_cut" },

    --=========================================================
    -- ANIMAL ATTACKS (Claws/teeth - high bleeding chance)
    --=========================================================
    [GetHashKey("WEAPON_BEAR")] = { bleeding = 5, chance = 0.95, data = "LargeAnimal", ballisticType = "animal", status = "claw_marks" },
    [GetHashKey("WEAPON_COUGAR")] = { bleeding = 4, chance = 0.9, data = "Predator", ballisticType = "animal", status = "claw_marks" },
    [GetHashKey("WEAPON_WOLF")] = { bleeding = 3, chance = 0.8, data = "Predator", ballisticType = "animal", status = "claw_marks" },
    [GetHashKey("WEAPON_WOLF_MEDIUM")] = { bleeding = 3, chance = 0.8, data = "Predator", ballisticType = "animal", status = "claw_marks" },
    [GetHashKey("WEAPON_WOLF_SMALL")] = { bleeding = 2, chance = 0.7, data = "SmallPredator", ballisticType = "animal", status = "claw_marks" },
    [GetHashKey("WEAPON_ALLIGATOR")] = { bleeding = 5, chance = 0.95, data = "LargeAnimal", ballisticType = "animal", status = "claw_marks" },
    [GetHashKey("WEAPON_COYOTE")] = { bleeding = 2, chance = 0.6, data = "SmallPredator", ballisticType = "animal", status = "claw_marks" },
    [GetHashKey("WEAPON_FOX")] = { bleeding = 1, chance = 0.4, data = "SmallAnimal", ballisticType = "animal", status = "claw_marks" },
    [GetHashKey("WEAPON_BADGER")] = { bleeding = 1, chance = 0.5, data = "SmallAnimal", ballisticType = "animal", status = "claw_marks" },
    [GetHashKey("WEAPON_SNAKE")] = { bleeding = 1, chance = 0.3, data = "Venomous", ballisticType = "animal", status = "claw_marks" },
    
    -- Non-aggressive animals (low bleeding, more trauma)
    [GetHashKey("WEAPON_HORSE")] = { bleeding = 1, chance = 0.2, data = "LargeAnimal", ballisticType = "animal", status = "claw_marks" },
    [GetHashKey("WEAPON_DEER")] = { bleeding = 1, chance = 0.15, data = "LargeAnimal", ballisticType = "animal", status = "claw_marks" },
    [GetHashKey("WEAPON_MUSKRAT")] = { bleeding = 0, chance = 0.05, data = "SmallAnimal", ballisticType = "animal", status = "claw_marks" },
    [GetHashKey("WEAPON_RACCOON")] = { bleeding = 0, chance = 0.1, data = "SmallAnimal", ballisticType = "animal", status = "claw_marks" },
    [GetHashKey("WEAPON_ANIMAL")] = { bleeding = 1, chance = 0.3, data = "Animal", ballisticType = "animal", status = "claw_marks" },

    --=========================================================
    -- IMPACT WEAPONS (Trauma, minimal bleeding)
    --=========================================================
    [GetHashKey("WEAPON_UNARMED")] = { bleeding = 0, chance = 0.0, data = "Unarmed", ballisticType = "melee", status = "bruise" },
    [GetHashKey("WEAPON_MELEE_HAMMER")] = { bleeding = 1, chance = 0.2, data = "BluntWeapon", ballisticType = "melee", status = "deep_cut" },

    --=========================================================
    -- EXPLOSIVES & FIRE (Severe trauma, high bleeding)
    --=========================================================
    [GetHashKey("WEAPON_DYNAMITE")] = { bleeding = 5, chance = 0.9, data = "Explosive", ballisticType = "explosive", status = "shrapnel" },
    [GetHashKey("WEAPON_THROWN_DYNAMITE")] = { bleeding = 5, chance = 0.9, data = "Explosive", ballisticType = "explosive", status = "shrapnel" },
    [GetHashKey("WEAPON_EXPLOSION")] = { bleeding = 6, chance = 0.95, data = "Explosion", ballisticType = "explosive", status = "shrapnel" },
    [GetHashKey("WEAPON_MOLOTOV")] = { bleeding = 3, chance = 0.7, data = "Fire", ballisticType = "fire", status = "deep_cut" },
    [GetHashKey("WEAPON_THROWN_MOLOTOV")] = { bleeding = 3, chance = 0.7, data = "Fire", ballisticType = "fire", status = "deep_cut" },
    [GetHashKey("WEAPON_FIRE")] = { bleeding = 2, chance = 0.4, data = "Fire", ballisticType = "fire", status = "deep_cut" },

    --=========================================================
    -- ENVIRONMENTAL DAMAGE (Low pain, minimal bleeding - heals naturally)
    --=========================================================
    [GetHashKey("WEAPON_FALL")] = { bleeding = 0, chance = 0.1, data = "Fall", ballisticType = "environmental", status = "bruise", pain = 3 },
    [GetHashKey("WEAPON_RAMMED_BY_CAR")] = { bleeding = 1, chance = 0.15, data = "VehicleImpact", ballisticType = "environmental", status = "deep_cut" },
    [GetHashKey("WEAPON_RUN_OVER_BY_CAR")] = { bleeding = 2, chance = 0.3, data = "VehicleImpact", ballisticType = "environmental", status = "deep_cut" },

    --=========================================================
    -- SUFFOCATION (No bleeding, pure trauma)
    --=========================================================
    [GetHashKey("WEAPON_DROWNING")] = { bleeding = 0, chance = 0.0, data = "Suffocation", ballisticType = "environmental", status = "deep_cut" },
    [GetHashKey("WEAPON_DROWNING_IN_VEHICLE")] = { bleeding = 0, chance = 0.0, data = "Suffocation", ballisticType = "environmental", status = "deep_cut" },

    --=========================================================
    -- BOW & ARROW SPECIAL CASE (Almost always lodge)
    --=========================================================
    [GetHashKey("WEAPON_BOW")] = { bleeding = 3, chance = 0.8, data = "Arrow", ballisticType = "bow", status = "arrow", lodgingChance = 95 },
    [GetHashKey("WEAPON_ARROW")] = { bleeding = 3, chance = 0.8, data = "Arrow", ballisticType = "bow", status = "arrow", lodgingChance = 95 },
}

--=========================================================
-- SMART BALLISTICS SYSTEM - Realistic Distance-Based Lodging
--=========================================================
-- Simple system that makes bullets behave realistically:
-- - Close range: High energy = bullets pass through
-- - Long range: Low energy = bullets lodge in body
-- - Weapon type affects how fast they lose energy over distance
--
-- EASY TO CONFIGURE: Just change the percentages per weapon type

Config.Ballistics = {
    enabled = true,                    -- Master on/off switch for entire system
    debugMode = true,                  -- Show distance/lodging calculations in chat (for testing)
    
    -- Distance ranges in meters (adjust these if needed)
    ranges = {
        shortRange = 25.0,             -- 0-25m = Short range
        mediumRange = 75.0,            -- 25-75m = Medium range
        longRange = 150.0              -- 75-150m = Long range, 150m+ = Extreme range
    },
    
    -- Base lodging chances by weapon category (0-100%)
    -- These get applied based on distance and weapon effectiveness ranges
    weaponCategories = {
        pistol = {
            name = "Pistols",
            shortRange = 0,            -- 0% lodging (always shot-through)
            mediumRange = 8,           -- 8% lodging chance
            longRange = 45,            -- 45% lodging chance
            extremeRange = 75,         -- 75% lodging chance
            maxEffectiveRange = 35.0,  -- Optimal range in meters
            description = "Short-range weapons that lose power quickly"
        },
        
        revolver = {
            name = "Revolvers", 
            shortRange = 0,            -- 0% lodging (always shot-through)
            mediumRange = 5,           -- 5% lodging chance
            longRange = 35,            -- 35% lodging chance
            extremeRange = 65,         -- 65% lodging chance
            maxEffectiveRange = 50.0,  -- Better range than pistols
            description = "More powerful than pistols, better penetration"
        },
        
        rifle = {
            name = "Rifles",
            shortRange = 0,            -- 0% lodging (always shot-through)
            mediumRange = 0,           -- 0% lodging (always shot-through)
            longRange = 15,            -- 15% lodging chance
            extremeRange = 40,         -- 40% lodging chance
            maxEffectiveRange = 120.0, -- Excellent long-range performance
            description = "High velocity, excellent penetration"
        },
        
        sniper = {
            name = "Sniper Rifles",
            shortRange = 0,            -- 0% lodging (always shot-through)
            mediumRange = 0,           -- 0% lodging (always shot-through)
            longRange = 5,             -- 5% lodging chance (very rare)
            extremeRange = 15,         -- 15% lodging chance (still rare)
            maxEffectiveRange = 200.0, -- Maximum long-range capability
            description = "Extreme velocity, almost never lodge"
        },
        
        shotgun = {
            name = "Shotguns",
            usePelletSystem = true,    -- Special pellet mechanics instead of single bullet
            shortRange = 70,           -- 70% of pellets embed
            mediumRange = 85,          -- 85% of pellets embed
            longRange = 95,            -- 95% of pellets embed
            extremeRange = 100,        -- 100% of pellets embed (no energy left)
            maxEffectiveRange = 40.0,  -- Limited by pellet spread
            pelletCount = 9,           -- Standard buckshot pellet count
            description = "Multiple pellets with rapid energy loss"
        }
    },
    
    -- Special weapon status effects (for when projectiles lodge/embed)
    specialStatuses = {
        arrow = "arrow_shaft",         -- "Arrow shaft protruding from chest"
        thrown_blade = "embedded_blade", -- "Knife embedded in left arm"  
        hatchet = "embedded_hatchet",  -- "Hatchet buried in shoulder"
        shrapnel = "metal_fragments",  -- "Metal fragments in wound"
        pellets = "shotgun_pellets",   -- "Shotgun pellets scattered in tissue"
        bullet = "lodged_bullet",      -- "Bullet lodged near spine"
        claw_marks = "lacerations",    -- "Deep claw marks"
        deep_cut = "laceration"        -- "Deep cutting wound"
    }
}

--=========================================================
-- BANDAGE SYSTEM - 4 Types with Time-Based Expiration
-- IMPORTANT: You can change the key names to match your item names!
-- Example: Change ['cotton'] to ['cotton_bandage'] and it will work automatically
--
-- SIMPLIFIED TIME-BASED MECHANICS:
-- - bleedingReduction: Immediate bleeding reduction when applied (minimum level 1 remains)
-- - Pain reduces proportionally to bleeding (since pain = bleeding + tissue damage)
-- - oneTimeHeal: Immediate health restoration when applied  
-- - decayRate: Minutes until bandage expires and 50% of reductions return
--
-- EXAMPLE TIMELINE (Cotton Bandage -4 reduction):
-- - Apply: Bleeding 8 -> 4, Pain 9 -> 5 (both reduce by 4, minimums: bleeding 1, pain 2)
-- - 5 minutes later: Bandage expires, bleeding 4 -> 6, pain 5 -> 7 (50% returns)
-- - 1 minute later: Infection risk begins if still bleeding
--=========================================================
Config.BandageTypes = {
    -- Basic cloth bandage - Low quality frontier treatment
    ['cloth'] = {
        label = 'Cloth Strip',
        itemName = 'cloth_band',     -- Actual item name in inventory (can be changed)
        decayRate = 3.0,                -- Minutes until bandage expires
        oneTimeHeal = 8,                -- Immediate health restored when applied
        bleedingReduction = 2,          -- Reduces bleeding level by 2 points (minimum 1 remains)
        description = 'Basic cloth strip - crude but available'
    },
    ['cotton'] = {
        label = 'Cotton Bandage',
        itemName = 'cotton_band',           -- Uses default RSG bandage item
        decayRate = 5.0,                -- Lasts 5 minutes before expiring
        oneTimeHeal = 12,               -- Decent immediate healing
        bleedingReduction = 4,          -- Reduces bleeding level by 4 points (minimum 1 remains)
        description = 'Standard cotton bandage - reliable frontier medicine'
    },
    ['linen'] = {
        label = 'Linen Wrap',
        itemName = 'linen_band',     -- Custom linen bandage item
        decayRate = 8.0,                -- Lasts 8 minutes before expiring
        oneTimeHeal = 18,               -- Good healing properties
        bleedingReduction = 6,          -- Reduces bleeding level by 6 points (minimum 1 remains)
        description = 'Quality linen wrap - superior absorbency and durability'
    },
    ['sterile'] = {
        label = 'Sterilized Gauze',
        itemName = 'sterile_band',   -- Medical grade bandage item
        decayRate = 12.0,               -- Lasts 12 minutes before expiring
        oneTimeHeal = 25,               -- Excellent healing
        bleedingReduction = 8,          -- Reduces bleeding level by 8 points (minimum 1 remains)
        description = 'Professional medical gauze - sterile and highly effective'
    }
}

--=========================================================
-- TOURNIQUET TYPES - Wild West 1899 Emergency Control
--=========================================================

Config.TourniquetTypes = {
    ['rope'] = {
        label = 'Rope Tourniquet',
        itemName = 'tourniquet_rope',    -- Actual item name in inventory
        effectiveness = 70,
        maxDuration = 1200,          -- 20 minutes max (rough material causes damage)
        damageAmount = 3,            -- Higher damage from coarse rope
        bleedingStopChance = 85,     -- Decent bleeding control
        oneTimeHeal = 0,             -- No healing, only bleeding control
        painIncrease = 15,           -- Causes significant pain
        description = 'Improvised rope tourniquet - rough but effective'
    },
    ['leather'] = {
        label = 'Leather Strap',
        itemName = 'tourniquet_leather', -- Actual item name in inventory
        effectiveness = 75,
        maxDuration = 1400,          -- 23 minutes max
        damageAmount = 2,            -- Moderate damage
        bleedingStopChance = 88,     -- Good bleeding control
        oneTimeHeal = 2,             -- Slight comfort benefit
        painIncrease = 12,           -- Moderate pain increase
        description = 'Leather strap tourniquet - durable frontier solution'
    },
    ['cloth'] = {
        label = 'Cloth Tourniquet',
        itemName = 'tourniquet_cloth',   -- Actual item name in inventory
        effectiveness = 65,
        maxDuration = 1000,          -- 16 minutes max (stretches out)
        damageAmount = 2,            -- Lower pressure damage
        bleedingStopChance = 80,     -- Basic bleeding control
        oneTimeHeal = 0,             -- No healing benefit
        painIncrease = 10,           -- Lower pain increase
        description = 'Cloth tourniquet - basic emergency bleeding control'
    },
    ['medical'] = {
        label = 'Medical Tourniquet',
        itemName = 'tourniquet_medical', -- Actual item name in inventory
        effectiveness = 95,
        maxDuration = 1800,          -- 30 minutes max (professional grade)
        damageAmount = 1,            -- Minimal damage when used properly
        bleedingStopChance = 98,     -- Excellent bleeding control
        oneTimeHeal = 5,             -- Professional application provides comfort
        painIncrease = 8,            -- Minimal additional pain
        description = 'Professional medical tourniquet - hospital grade'
    }
}

--=========================================================
-- MEDICINE TYPES - Wild West 1899 Pharmaceutical Treatment
--=========================================================

Config.MedicineTypes = {
    ['laudanum'] = {
        label = 'Laudanum',
        itemName = 'medicine_laudanum',  -- Actual item name in inventory
        description = 'Opium-based painkiller - powerful but addictive',
        price = 35,                  -- $35 per bottle
        effectiveness = 85,
        healAmount = 25,             -- Strong pain relief and healing
        duration = 300,              -- 5 minutes effect
        sideEffects = {'drowsiness', 'euphoria'},
        conditions = {'severe_pain', 'post_surgery', 'chronic_pain'},
        addictionRisk = 15           -- 15% chance of dependency
    },
    ['morphine'] = {
        label = 'Morphine Powder',
        itemName = 'medicine_morphine',  -- Actual item name in inventory
        description = 'Powerful opiate analgesic - strongest painkiller available',
        price = 50,                  -- $50 per dose
        effectiveness = 95,
        healAmount = 35,             -- Strongest pain relief
        duration = 450,              -- 7.5 minutes effect
        sideEffects = {'respiratory_depression', 'euphoria', 'confusion'},
        conditions = {'critical_pain', 'major_surgery', 'dying'},
        addictionRisk = 25           -- High addiction risk
    },
    ['whiskey'] = {
        label = 'Medicinal Whiskey',
        itemName = 'medicine_whiskey',   -- Actual item name in inventory
        description = 'Alcohol-based antiseptic and anesthetic - frontier medicine',
        price = 15,                  -- $15 per bottle
        effectiveness = 60,
        healAmount = 10,             -- Basic pain numbing
        duration = 180,              -- 3 minutes effect
        sideEffects = {'intoxication', 'impaired_judgment'},
        conditions = {'minor_pain', 'wound_cleaning', 'pre_surgery'},
        addictionRisk = 8            -- Moderate addiction risk
    },
    ['quinine'] = {
        label = 'Quinine Powder',
        itemName = 'medicine_quinine',   -- Actual item name in inventory
        description = 'Antimalarial and fever reducer - specialized treatment',
        price = 25,                  -- $25 per dose
        effectiveness = 70,
        healAmount = 15,             -- Specific for fever and malaria
        duration = 600,              -- 10 minutes effect
        sideEffects = {'nausea', 'ringing_ears'},
        conditions = {'fever', 'malaria', 'infection'},
        addictionRisk = 0            -- No addiction potential
    }
}

--=========================================================
-- INJECTION TYPES - Wild West 1899 Experimental Medical Injections
--=========================================================

Config.InjectionTypes = {
    ['adrenaline'] = {
        label = 'Adrenaline Shot',
        itemName = 'injection_adrenaline',  -- Actual item name in inventory
        description = 'Cardiac stimulant for emergency resuscitation - use with extreme caution',
        price = 75,                  -- $75 per injection (expensive/experimental)
        effectiveness = 90,
        healAmount = 45,             -- Immediate life-saving effect
        duration = 120,              -- 2 minutes intense effect
        sideEffects = {'rapid_heartbeat', 'anxiety', 'tremors'},
        conditions = {'cardiac_arrest', 'shock', 'unconscious'},
        riskLevel = 'high',          -- Dangerous if misused
        overdoseRisk = 20            -- 20% chance of complications
    },
    ['cocaine'] = {
        label = 'Cocaine Solution',
        itemName = 'injection_cocaine',     -- Actual item name in inventory
        description = 'Local anesthetic for surgical procedures - numbs pain effectively',
        price = 40,                  -- $40 per injection
        effectiveness = 80,
        healAmount = 20,             -- Pain blocking for surgery
        duration = 240,              -- 4 minutes effect
        sideEffects = {'numbness', 'euphoria', 'increased_alertness'},
        conditions = {'surgery', 'severe_laceration', 'amputation'},
        riskLevel = 'medium',
        overdoseRisk = 15            -- Moderate overdose risk
    },
    ['strychnine'] = {
        label = 'Strychnine (Micro)',
        itemName = 'injection_strychnine',  -- Actual item name in inventory
        description = 'Stimulant for paralysis and respiratory failure - extremely dangerous',
        price = 60,                  -- $60 per injection (dangerous = expensive)
        effectiveness = 70,
        healAmount = 30,             -- Dangerous but effective stimulant
        duration = 180,              -- 3 minutes effect
        sideEffects = {'muscle_spasms', 'hyperalertness', 'convulsions'},
        conditions = {'paralysis', 'respiratory_failure', 'coma'},
        riskLevel = 'extreme',       -- Extremely dangerous
        overdoseRisk = 35            -- High chance of fatal overdose
    },
    ['saline'] = {
        label = 'Salt Water',
        itemName = 'injection_saline',      -- Actual item name in inventory
        description = 'Hydration and blood volume replacement - safe basic treatment',
        price = 10,                  -- $10 per injection (basic/safe)
        effectiveness = 50,
        healAmount = 15,             -- Basic hydration support
        duration = 600,              -- 10 minutes gradual effect
        sideEffects = {'mild_nausea'},
        conditions = {'dehydration', 'blood_loss', 'shock'},
        riskLevel = 'low',           -- Very safe
        overdoseRisk = 2             -- Minimal risk
    }
}

--=========================================================
-- DOCTOR'S BAG DIAGNOSTIC TOOLS - Wild West 1899 Medical Equipment
--=========================================================
-- NOTE: laudanum and whiskey are already in Config.MedicineTypes above
-- These are specialized diagnostic/surgical tools for medics

Config.DoctorsBagTools = {
    ['smelling_salts'] = {
        label = 'Smelling Salts',
        itemName = 'smelling_salts',        -- Item name in inventory
        action = 'revive_unconscious',      -- Action to perform
        description = 'Revive unconscious patients',
        consumable = true,                  -- Consumed on use
        price = 20,                         -- $20 per vial
        medicOnly = true                    -- Only medics can use
    },
    ['stethoscope'] = {
        label = 'Stethoscope',
        itemName = 'stethoscope',
        action = 'check_heart_lungs',
        description = 'Check heart and lung sounds',
        consumable = false,                 -- Reusable tool
        price = 45,                         -- $45 purchase price
        medicOnly = true
    },
    ['thermometer'] = {
        label = 'Thermometer',
        itemName = 'thermometer',
        action = 'check_temperature',
        description = 'Measure body temperature',
        consumable = false,                 -- Reusable tool
        price = 25,                         -- $25 purchase price
        medicOnly = true
    },
    ['field_surgery_kit'] = {
        label = 'Field Surgery Kit',
        itemName = 'field_surgery_kit',
        action = 'emergency_surgery',
        description = 'Emergency surgical tools for field operations',
        consumable = true,                  -- Each use consumes supplies
        price = 100,                        -- $100 per kit
        medicOnly = true
    }
}

--=========================================================
-- Tourniquet System Configuration
--=========================================================

Config.Tourniquet = {
    enabled = true,
    maxDuration = 1800,           -- 30 minutes max duration in seconds
    damageInterval = 60,          -- Apply damage every 60 seconds
    damageAmount = 2,             -- Damage dealt per interval when over max duration
    bleedingStopChance = 95,      -- 95% chance to stop bleeding
    applicationTime = 8000,       -- 8 seconds to apply tourniquet
    removalTime = 5000,           -- 5 seconds to remove tourniquet
    warningTime = 1200,           -- Warn after 20 minutes (1200 seconds)
    applicableParts = {           -- Body parts where tourniquets can be applied
        'LARM', 'RARM', 'LLEG', 'RLEG', 'LHAND', 'RHAND', 'LFOOT', 'RFOOT'
    }
}



--=========================================================
-- UI COLOR SYSTEM (Priority-based hierarchy)
--=========================================================

Config.UI = {
    -- Color hierarchy: bandaged > tourniquet > infected > health-based
    colors = {
        -- Treatment status colors (highest priority)
        bandaged = '#3498db',          -- Blue - has active bandage
        tourniquet = '#f1c40f',        -- Yellow - has active tourniquet
        infected = '#9C27B0',          -- Purple - has active infection
        
        -- Health-based colors (only show if no treatments/infections)
        normal = '#27ae60',            -- Green - 70%+ health
        medium = '#f39c12',            -- Orange - 30-70% health  
        low = '#e74c3c',               -- Red - <30% health
        
        -- Special states
        white = '#EEE6D2',             -- Default/unknown
        green = '#27ae60',             -- Healthy override
        darkred = '#8B0000'            -- Critical/emergency
    }
}


--=========================================================
-- INFECTION & DISEASE SYSTEM
--=========================================================

Config.InfectionSystem = {
    enabled = true,                         -- Enable/disable entire infection system
    
    -- ========================================
    -- UNIFIED TIMING SETTINGS
    -- ========================================
    -- Uses same timing as wound progression (2 minutes) for efficiency
    progressionInterval = 120000,           -- 2 minutes (same as wound progression)
    
    -- ========================================  
    -- INFECTION TRIGGER SETTINGS
    -- ========================================
    dirtyBandageGracePeriod = 60,           -- Seconds after bandage effectiveness expires before infection risk (1 minute for testing)
    baseInfectionChance = 15,               -- Base 15% infection chance per tick with dirty bandage
    
    -- ========================================
    -- WOUND TYPE INFECTION MULTIPLIERS
    -- ========================================  
    -- Multiplies baseInfectionChance based on bullet penetration type
    woundTypeMultipliers = {
        bullet_stuck = 2.0,         -- Lodged bullet = 30% chance (15 × 2.0)
        bullet_fragmented = 2.5,    -- Bullet fragments = 37.5% chance (15 × 2.5)  
        bullet_through = 1.0,       -- Clean through = 15% chance (15 × 1.0)
        default = 1.2               -- Other wounds = 18% chance (15 × 1.2)
    },
    
    -- ========================================
    -- PERCENTAGE-BASED INFECTION PROGRESSION
    -- ========================================
    -- Infection builds up percentage over time until stage thresholds reached
    infectionPercentagePerTick = 10,        -- 10% infection buildup per progression tick
    
    -- ========================================
    -- INFECTION STAGES - 4 stages progression
    -- ========================================
    -- Each stage has symptoms, effects, and progression chance
    -- Effects apply every stageInterval (60 seconds for testing, 600 for production)
    -- 
    -- HEALTH DAMAGE GUIDE (Max Health = 600):
    -- - Stage 1: 1-3 damage = Very mild (can survive 200+ ticks)
    -- - Stage 2: 3-8 damage = Mild (can survive 75+ ticks) 
    -- - Stage 3: 8-15 damage = Serious (can survive 40+ ticks)
    -- - Stage 4: 15-25 damage = Critical (can survive 24+ ticks)
    stages = {
        [1] = {
            name = "Early Infection",
            minPercent = 25,                -- Triggers at 25% infection
            maxPercent = 49,                -- Stage 1: 25-49%
            symptom = "You feel a burning sensation around your bandage",
            effects = {
                staminaDrain = 8.0,         -- Noticeable stamina drain
                temperatureChange = 0.5,    -- Mild fever (no visual effects)
                movementPenalty = 5.0       -- 5% movement speed reduction
            }
        },
        [2] = {
            name = "Moderate Infection", 
            minPercent = 50,                -- Triggers at 50% infection
            maxPercent = 74,                -- Stage 2: 50-74%
            symptom = "The area around your bandage is becoming red and swollen",
            effects = {
                staminaDrain = 15.0,        -- Heavy stamina drain
                temperatureChange = 1.0,    -- Low fever (mild visual effects)
                movementPenalty = 15.0      -- 15% movement speed reduction
            }
        },
        [3] = {
            name = "Serious Infection",
            minPercent = 75,                -- Triggers at 75% infection
            maxPercent = 89,                -- Stage 3: 75-89%
            symptom = "The infection is causing significant pain and inflammation", 
            effects = {
                staminaDrain = 25.0,        -- Severe stamina drain  
                temperatureChange = 1.5,    -- High fever (noticeable effects)
                movementPenalty = 25.0      -- 25% movement speed reduction
            }
        },
        [4] = {
            name = "Severe Infection",
            minPercent = 90,                -- Triggers at 90% infection
            maxPercent = 100,               -- Stage 4: 90-100%
            symptom = "The infection is spreading and causing high fever",
            effects = {
                staminaDrain = 40.0,        -- Extreme stamina drain
                temperatureChange = 2.5,    -- Very high fever (strong visual effects)
                movementPenalty = 45.0      -- 45% movement speed reduction
            }
        }
    },
    
    -- ========================================
    -- CURE ITEMS - Gradual healing system
    -- ========================================
    -- Items slowly reduce infection over multiple uses
    -- Configure these to match your server's available items
    cureItems = {
        ['antibiotics'] = {
            label = 'Antibiotics',
            itemName = 'antibiotics',       -- Your inventory item name
            cureProgress = 40.0,            -- 40% cure progress per use (gradual healing)
            treatmentTime = 15000,          -- 15 seconds to apply
            preventReinfection = 3600,      -- Prevents reinfection for 1 hour
            description = 'Modern medicine - most effective treatment'
        },
        ['alcohol'] = {
            label = 'Alcohol',
            itemName = 'alcohol',           -- Your inventory item name  
            cureProgress = 25.0,            -- 25% cure progress per use (slower healing)
            treatmentTime = 8000,           -- 8 seconds to apply
            preventReinfection = 1800,      -- Prevents reinfection for 30 minutes
            description = 'Disinfectant - moderate effectiveness'
        },
        ['cocaine'] = {
            label = 'Cocaine', 
            itemName = 'cocaine',           -- Your inventory item name
            cureProgress = 15.0,            -- 15% cure progress per use (very slow)
            treatmentTime = 5000,           -- 5 seconds to apply
            preventReinfection = 600,       -- Prevents reinfection for 10 minutes
            description = 'Pain relief with mild antiseptic properties'
        }
    },
    
    -- ========================================
    -- DEBUGGING CONFIGURATION
    -- ========================================
    debugging = {
        enabled = true,                     -- Enable/disable debug prints (SET TO FALSE FOR PRODUCTION)
        printPercentages = true,            -- Show infection chance percentages
        printProgression = true,            -- Show stage progression
        printCureProgress = true,           -- Show cure progress
        verboseLogging = true               -- Detailed debug output
    },
    
    -- Notification Settings
    notifications = {
        infectionStart = {
            title = 'Infection Detected',
            type = 'error',
            duration = 8000
        },
        infectionProgression = {
            title = 'Infection Worsening',
            type = 'error', 
            duration = 6000
        },
        infectionCured = {
            title = 'Infection Cured',
            type = 'success',
            duration = 5000
        },
        dirtyBandageWarning = {
            title = 'Dirty Bandage Warning',
            type = 'warning',
            duration = 6000
        }
    }

}

--=========================================================
-- WOUND HEALING SYSTEM CONFIGURATION
--=========================================================
-- Wounds heal to scars when properly cared for (bandaged + bleeding level 1)
-- If conditions are broken (bandage expires, bleeding increases), timer resets

Config.WoundHealing = {
    enabled = true,                     -- Enable wound healing to scars system
    
    -- Healing times for different wound types (in minutes)
    -- Requirements: bandaged + bleeding level 1 + maintained for full duration
    healingTimes = {
        -- Shot-through wounds (bullet passed through cleanly)
        ["shot_through"] = {
            healTime = 15,  -- 15 minutes of proper care
            description = "Clean bullet wound - heals relatively quickly with proper care",
            scarType = "entry_exit_scar"
        },
        
        -- Post-surgery wounds (bullet was lodged but surgically removed)  
        ["post_surgery"] = {
            healTime = 25,  -- 25 minutes of proper care
            description = "Surgical wound from bullet removal - needs extended care", 
            scarType = "surgical_scar"
        },
        
        -- Fragmented wounds (bullet broke apart, multiple fragments)
        ["fragmented"] = {
            healTime = 35,  -- 35 minutes of proper care
            description = "Complex fragmented wound - requires intensive care",
            scarType = "complex_scar"
        },
        
        -- Cutting wounds (knives, blades, claws)
        ["cutting"] = {
            healTime = 10,  -- 10 minutes of proper care
            description = "Clean cut wound - heals quickly when properly sutured",
            scarType = "linear_scar"
        },
        
        -- Crushing wounds (blunt trauma, animal attacks)
        ["crushing"] = {
            healTime = 20,  -- 20 minutes of proper care
            description = "Blunt trauma wound - tissue damage requires time to heal",
            scarType = "irregular_scar"
        },
        
        -- Explosive wounds (shrapnel, burns)
        ["explosive"] = {
            healTime = 40,  -- 40 minutes of proper care
            description = "Severe explosive trauma - extensive healing time required",
            scarType = "burn_scar"
        },
        
        -- Default fallback for unknown wound types
        ["default"] = {
            healTime = 20,  -- 20 minutes default
            description = "Unknown wound type - standard healing time",
            scarType = "standard_scar"
        }
    },
    
    -- Healing notifications
    notifications = {
        healingStarted = {
            title = "Wound Healing",
            type = "inform", 
            duration = 6000
        },
        healingInterrupted = {
            title = "Healing Interrupted",
            type = "warning",
            duration = 8000  
        },
        healingComplete = {
            title = "Wound Healed",
            type = "success",
            duration = 10000
        }
    },
    
    -- Debugging settings
    debugging = {
        enabled = true,                    -- Enable healing debug messages
        showHealingProgress = true,        -- Show healing timer progress
        showRequirementChecks = true      -- Show when requirements are checked
    }
}

Config.Strings = {}

-- Function to load locale strings
local function LoadLocaleStrings()
    local localeFile = LoadResourceFile(GetCurrentResourceName(), 'locales/' .. Config.Locale .. '.json')
    if localeFile then
        local success, localeData = pcall(json.decode, localeFile)
        if success and localeData then
            Config.Strings = localeData
            print(string.format('^2[QC-AdvancedMedic] Loaded %s locale with %d strings^7', Config.Locale, #localeData))
        else
            print(string.format('^1[QC-AdvancedMedic] Failed to parse locale file: %s^7', Config.Locale))
            -- Fallback to English
            Config.Locale = 'en'
            LoadLocaleStrings()
        end
    else
        print(string.format('^1[QC-AdvancedMedic] Locale file not found: %s^7', Config.Locale))
        if Config.Locale ~= 'en' then
            Config.Locale = 'en'
            LoadLocaleStrings()
        end
    end
end


LoadLocaleStrings()

Citizen.CreateThread(function()
    Wait(1000)
    if Config.Strings and next(Config.Strings) then
        -- Config strings loaded successfully
    else
        print('^1[QC-AdvancedMedic] ERROR: Config.Strings is empty in config.lua!^7')
    end
end)

function GetString(key, fallback)
    return Config.Strings[key] or fallback or key
end