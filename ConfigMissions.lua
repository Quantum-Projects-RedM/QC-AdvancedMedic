--=========================================================
--               QC-ADVANCED MEDIC MISSION CONFIGURATION
--=========================================================
-- IMPORTANT: This file contains all mission configurations
-- for the medic training system. Each mission is designed
-- to train medics using the same mechanics as player-to-player
-- medical inspections and treatments.
--=========================================================

ConfigMissions = {}

--=========================================================
-- Enhanced Medic Mission System
-- Mission Types:
-- - 'field': Basic field treatment with bandages only
-- - 'intermediate': Multi-step field treatment with multiple procedures
-- - 'surgery': Advanced cases requiring transport to medical station for surgery
--=========================================================
ConfigMissions.BandageItem = 'fieldbandage'
--=========================================================
-- Mission Locations - Job-Specific Areas
--=========================================================
ConfigMissions.Locations = {
    -- Valentine Area (valmedic job)
    valentine = {
        job = "valmedic",
        locations = {
            vector4(-168.4427, 640.6234, 114.0321, 318.2941),  -- Valentine outskirts
            vector4(-340.2156, 783.4821, 116.3654, 85.7234),   -- Valentine north
            vector4(-128.57, 897.56, 169.07, 242.90),  -- Valentine farms
            vector4(-276.84, 521.50, 95.66, 242.77),  -- Valentine south
            vector4(-74.68, 680.81, 115.73, 242.77)     -- Valentine east
        }
    },
    -- Saint Denis Area (sdmedic job) 
    saintdenis = {
        job = "sdmedic",
        locations = {
            vector4(2851.4729, -1220.5145, 47.5868, 130.9617),  -- Saint Denis docks
            vector4(2749.6234, -1389.4828, 46.2318, 345.1793),  -- Saint Denis industrial
            vector4(2950.1234, -1150.7896, 52.4321, 265.8974),  -- Saint Denis north
            vector4(2654.7891, -1425.3698, 48.9874, 125.6547),  -- Saint Denis south
            vector4(2780.4569, -1050.1234, 55.7412, 85.3698)    -- Saint Denis residential
        }
    },
    -- Strawberry Area (sbmedic job)
    strawberry = {
        job = "sbmedic", 
        locations = {
            vector4(-1328.2313, -1292.1934, 77.0241, 322.4265), -- Strawberry hills
            vector4(-1450.7896, -1150.4561, 85.7412, 185.9632), -- Strawberry valley
            vector4(-1200.3698, -1380.7410, 69.8521, 95.7418),  -- Strawberry woods
            vector4(-1520.1478, -1050.9637, 92.1485, 275.8520), -- Strawberry peaks
            vector4(-1075.9514, -1200.7531, 73.6985, 145.2074)  -- Strawberry creek
        }
    }
}

--=========================================================
-- Mission Types (No coords - uses random location based on job)
--=========================================================
ConfigMissions.MedicMissions = {
    -- Field Mission 1: Simple Knife Laceration - LARM
    [1] = {
        pedModel = 'rcsp_ridethelightning_males_01',
        animDict = 'script_story@gua2@ig@ig_walkcollapse',
        animName = 'gua2_collapse_rf',
        blipName = 'Emergency Patient',
        blipSprite = 'blip_supply_icon_health',
        blipColor = 1,
        missionType = 'field', -- field, intermediate, surgery
        -- Medical condition matching real wound system
        patientData = {
            playerName = "John Smith",
            citizenid = "NPC001",
            source = -1, -- NPC marker
            -- Using exact same structure as player inspection
            wounds = {
                LARM = {
                    painLevel = 4,
                    bleedingLevel = 3,
                    healthPercentage = 70,
                    weaponClass = 'WEAPON_MELEE_KNIFE',
                    description = "Deep laceration to the left forearm caused by a sharp knife blade. Clean cut edges with active bleeding. Wound appears fresh and will require thorough cleaning and suturing to prevent infection."
                }
            },
            treatments = {},
            infections = {},
            bandages = {},
            -- Health data using exact same calculation as players
            healthData = {
                LARM = { current = 70, max = 100, percentage = 70 },
                RARM = { current = 100, max = 100, percentage = 100 },
                LLEG = { current = 100, max = 100, percentage = 100 },
                RLEG = { current = 100, max = 100, percentage = 100 },
                HEAD = { current = 100, max = 100, percentage = 100 },
                UPPER_BODY = { current = 100, max = 100, percentage = 100 }
            },
            bloodLevel = 65.0,
            isBleeding = true,
            description = "Patient suffered a deep laceration to the left arm from a knife wound. Active bleeding present, requires immediate attention.",
            difficulty = "beginner"
        }
    },
    -- Intermediate Mission 2: Bear Mauling - Multiple Wounds  
    [2] = {
        pedModel = 'rcsp_ridethelightning_males_01',
        animDict = 'script_story@gua2@ig@ig_walkcollapse',
        animName = 'gua2_collapse_rf',
        blipName = 'Critical Patient',
        blipSprite = 'blip_supply_icon_health',
        blipColor = 2,
        missionType = 'intermediate',
        -- Medical condition matching real wound system
        patientData = {
            playerName = "Maria Rodriguez",
            citizenid = "NPC002",
            source = -1, -- NPC marker
            -- Multiple wounds from bear attack
            wounds = {
                RLEG = {
                    painLevel = 6,
                    bleedingLevel = 5,
                    healthPercentage = 25,
                    weaponClass = 'WEAPON_BEAR',
                    description = "Severe lacerations from bear claws on the right thigh. Multiple deep, parallel claw marks with torn muscle tissue and heavy arterial bleeding. Immediate tourniquet required to control blood loss."
                },
                LARM = {
                    painLevel = 5,
                    bleedingLevel = 4,
                    healthPercentage = 40,
                    weaponClass = 'WEAPON_BEAR',
                    description = "Bear claw wounds across the left forearm. Multiple puncture wounds with ragged edges and moderate bleeding. Defensive wounds consistent with patient attempting to ward off attack."
                },
                UPPER_BODY = {
                    painLevel = 4,
                    bleedingLevel = 3,
                    healthPercentage = 55,
                    weaponClass = 'WEAPON_BEAR',
                    description = "Superficial claw marks across the chest and shoulder area. Scratches are bleeding but not deep enough to damage vital structures. Patient shows signs of shock and trauma."
                }
            },
            treatments = {},
            infections = {},
            bandages = {},
            -- Health data reflecting multiple severe wounds
            healthData = {
                LARM = { current = 40, max = 100, percentage = 40 },
                RARM = { current = 100, max = 100, percentage = 100 },
                LLEG = { current = 100, max = 100, percentage = 100 },
                RLEG = { current = 25, max = 100, percentage = 25 }, -- Most severe
                HEAD = { current = 100, max = 100, percentage = 100 },
                UPPER_BODY = { current = 55, max = 100, percentage = 55 }
            },
            bloodLevel = 35.0,
            isBleeding = true,
            description = "Patient mauled by bear. Multiple severe lacerations with arterial bleeding. Critical condition requiring immediate multi-step intervention.",
            difficulty = "intermediate"
        }
    },
    -- Surgery Mission 3: Gunshot and Fall Trauma - Multiple Critical Wounds
    [3] = {
        pedModel = 'rcsp_ridethelightning_males_01',
        animDict = 'script_story@gua2@ig@ig_walkcollapse',
        animName = 'gua2_collapse_rf',
        blipName = 'Multi-Trauma Patient',
        blipSprite = 'blip_supply_icon_health',
        blipColor = 3,
        missionType = 'surgery',
        -- Medical condition matching real wound system
        patientData = {
            playerName = "Thomas Wilson",
            citizenid = "NPC003",
            source = -1, -- NPC marker
            -- Complex multi-trauma wounds
            wounds = {
                HEAD = {
                    painLevel = 4,
                    bleedingLevel = 3,
                    healthPercentage = 15,
                    weaponClass = 'WEAPON_FALL',
                    requiresSurgery = true,
                    description = "Severe head trauma from fall. Visible depression in skull with active bleeding from scalp lacerations. Patient shows signs of increased intracranial pressure and requires immediate surgical intervention to prevent permanent brain damage."
                },
                UPPER_BODY = {
                    painLevel = 4,
                    bleedingLevel = 3,
                    healthPercentage = 20,
                    weaponClass = 'WEAPON_RIFLE_SPRINGFIELD',
                    requiresSurgery = true,
                    description = "High-velocity rifle bullet wound to the chest. Large entry wound with probable internal organ damage and internal bleeding. Patient is in critical condition and requires emergency surgery to repair damaged organs and control hemorrhaging."
                },
                RLEG = {
                    painLevel = 3,
                    bleedingLevel = 2,
                    healthPercentage = 30,
                    weaponClass = 'WEAPON_FALL',
                    requiresSurgery = false,
                    description = "Compound fracture of the right tibia from fall. Bone fragments are visible through the skin with moderate bleeding. Requires splinting and surgical repair, but not immediately life-threatening if properly stabilized."
                }
            },
            treatments = {},
            infections = {},
            bandages = {},
            -- Health data reflecting critical multi-trauma
            healthData = {
                LARM = { current = 100, max = 100, percentage = 100 },
                RARM = { current = 100, max = 100, percentage = 100 },
                LLEG = { current = 100, max = 100, percentage = 100 },
                RLEG = { current = 30, max = 100, percentage = 30 }, -- Severe fracture
                HEAD = { current = 15, max = 100, percentage = 15 }, -- Critical head trauma
                UPPER_BODY = { current = 20, max = 100, percentage = 20 } -- Gunshot wound
            },
            bloodLevel = 25.0,
            isBleeding = true,
            description = "Critical multi-trauma patient from carriage accident and gunfight. Head trauma and thoracic gunshot wound require immediate surgical intervention.",
            difficulty = "advanced"
        }
    },
    -- Field Mission 4: Shotgun Wound - Pellet Injuries
    [4] = {
        pedModel = 'rcsp_ridethelightning_males_01',
        animDict = 'script_story@gua2@ig@ig_walkcollapse',
        animName = 'gua2_collapse_rf',
        blipName = 'Shotgun Wound Patient',
        blipSprite = 'blip_supply_icon_health',
        blipColor = 1,
        missionType = 'field',
        patientData = {
            playerName = "Jacob Miller",
            citizenid = "NPC004", 
            source = -1,
            wounds = {
                UPPER_BODY = {
                    painLevel = 5,
                    bleedingLevel = 4,
                    healthPercentage = 45,
                    weaponClass = 'WEAPON_SHOTGUN_DOUBLEBARREL',
                    description = "Multiple shotgun pellet wounds across the chest. Scattered pattern of small entry wounds with embedded pellets causing significant bleeding. Some pellets may need surgical removal, but patient is stable for field treatment."
                },
                RARM = {
                    painLevel = 4,
                    bleedingLevel = 3,
                    healthPercentage = 55,
                    weaponClass = 'WEAPON_SHOTGUN_DOUBLEBARREL',
                    description = "Shotgun pellet wounds to the right arm. Multiple small puncture wounds with moderate bleeding. Pellet spread pattern indicates shot fired from medium range. Wounds are superficial but numerous."
                }
            },
            treatments = {},
            infections = {},
            bandages = {},
            healthData = {
                LARM = { current = 100, max = 100, percentage = 100 },
                RARM = { current = 55, max = 100, percentage = 55 },
                LLEG = { current = 100, max = 100, percentage = 100 },
                RLEG = { current = 100, max = 100, percentage = 100 },
                HEAD = { current = 100, max = 100, percentage = 100 },
                UPPER_BODY = { current = 45, max = 100, percentage = 45 }
            },
            bloodLevel = 55.0,
            isBleeding = true,
            description = "Patient caught in hunting accident. Multiple pellet wounds to torso and arm, widespread bleeding pattern typical of shotgun injuries.",
            difficulty = "intermediate"
        }
    },
    -- Intermediate Mission 5: Revolver Wound - Through and Through
    [5] = {
        pedModel = 'rcsp_ridethelightning_males_01',
        animDict = 'script_story@gua2@ig@ig_walkcollapse',
        animName = 'gua2_collapse_rf',
        blipName = 'Gunshot Victim',
        blipSprite = 'blip_supply_icon_health',
        blipColor = 2,
        missionType = 'intermediate',
        patientData = {
            playerName = "Sarah O'Malley",
            citizenid = "NPC005",
            source = -1,
            wounds = {
                LLEG = {
                    painLevel = 3,
                    bleedingLevel = 2,
                    healthPercentage = 60,
                    weaponClass = 'WEAPON_REVOLVER_SCHOFIELD',
                    description = "Clean through-and-through bullet wound to the left thigh from a .45 Schofield revolver. Entry and exit wounds are visible with moderate bleeding. Bullet appears to have missed major arteries and bone. Good prognosis with proper wound care."
                }
            },
            treatments = {},
            infections = {},
            bandages = {},
            healthData = {
                LARM = { current = 100, max = 100, percentage = 100 },
                RARM = { current = 100, max = 100, percentage = 100 },
                LLEG = { current = 60, max = 100, percentage = 60 },
                RLEG = { current = 100, max = 100, percentage = 100 },
                HEAD = { current = 100, max = 100, percentage = 100 },
                UPPER_BODY = { current = 100, max = 100, percentage = 100 }
            },
            bloodLevel = 70.0,
            isBleeding = true,
            description = "Patient shot in the leg during saloon altercation. Clean through-and-through wound with moderate bleeding.",
            difficulty = "intermediate"
        }
    }
}

--=========================================================
-- Mission Settings and Configuration
--=========================================================
ConfigMissions.Settings = {
    -- Medical station coordinates for transport missions
    medicalStationCoords = vector3(-283.42, 807.11, 119.38),
    surgeryRoomCoords = vector3(-283.42, 807.11, 119.38),
    transportRange = 5.0, -- Distance to be considered "at location"
    
    -- Mission timeouts and timing
    missionTimeout = 1800, -- 30 minutes
    blipUpdateInterval = 5000, -- Update mission blip every 5 seconds
    
    -- Mission difficulty settings
    difficulties = {
        beginner = { timeBonus = 1.5, payMultiplier = 1.0 },
        intermediate = { timeBonus = 1.25, payMultiplier = 1.5 },
        advanced = { timeBonus = 1.0, payMultiplier = 2.0 }
    }
}