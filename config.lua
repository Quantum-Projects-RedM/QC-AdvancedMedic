Config = {}

-- Settings
Config.Debug                    = false
Config.JobRequired              = 'medic'
Config.Image = "rsg-inventory/html/images/"

Config.DeathTimer               = 300 -- 300 = 5 mins / testing 60 = 1 min
Config.WipeInventoryOnRespawn   = false
Config.WipeCashOnRespawn        = false
Config.WipeBloodmoneyOnRespawn  = false
Config.MaxHealth                = 600
Config.MedicReviveTime          = 5000
Config.MedicTreatTime           = 5000
Config.AddGPSRoute              = true
Config.MedicCallDelay           = 60 -- delay in seconds before calling medic again
Config.BandageTime              = 10000
Config.BandageHealth            = 100
Config.ResetOutlawStatus        = false
Config.UseScreenEffects         = true     -- Effects for wounds/bleeding states 

-- Blip Settings
Config.Blip =
{
    blipName   = 'Medic', -- Config.Blip.blipName
    blipSprite = 'blip_shop_doctor', -- Config.Blip.blipSprite
    blipScale  = 0.2 -- Config.Blip.blipScale
}
-------------------------------------------------
---   Location STORAGE INFO
-------------------------------------------------
Config.StorageMaxWeight         = 4000000
Config.StorageMaxSlots          = 48
-------------------------------------------------
---   BAG STORAGE INFO
-------------------------------------------------
Config.BagMaxWeight         = 1000000
Config.BagMaxSlots          = 10

---------------------------------
-- Bag Crafting Items
---------------------------------
Config.MedicBagCrafting = {
    {
        category = 'First Aid',
        crafttime = 30000,
        craftingrep = 0,
        ingredients = { 
            [1] = { item = 'cotton', amount = 1 },
        },
        receive = 'bandage',
        giveamount = 1
    },
}

-- Prompt Locations
Config.MedicJobLocations =
{
    {name = 'Valentine Medic', prompt = 'valmedic', coords = vector3(-287.59, 811.28, 119.39 -0.8), showblip = true} -- Valentine
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
    [9] = {coords = vector4(3016.71, 1345.64, 42.69, 67.85)} -- Annesburg
}

Config.WeaponClasses = {
    ['SMALL_CALIBER'] = 1,
    ['MEDIUM_CALIBER'] = 2,
    ['HIGH_CALIBER'] = 3,
    ['SHOTGUN'] = 4,
    ['CUTTING'] = 5,
    ['LIGHT_IMPACT'] = 6,
    ['HEAVY_IMPACT'] = 7,
    ['EXPLOSIVE'] = 8,
    ['FIRE'] = 9,
    ['SUFFOCATING'] = 10,
    ['OTHER'] = 11,
    ['WILDLIFE'] = 12,
    ['NOTHING'] = 13
}

Config.WoundStates = {
    'a slight irritation',
    'a lot of pain',
    'extreme pain',
    'unbearable pain',
}

Config.BleedingStates = {
    'light bleeding',
    'significant bleeding',
    'severe bleeding',
    'extreme bleeding',
}

Config.weapons = {
    -- Small Caliber
    [`WEAPON_REVOLVER_CATTLEMAN`] = Config.WeaponClasses['SMALL_CALIBER'],
    [`WEAPON_REVOLVER_CATTLEMAN_JOHN`] = Config.WeaponClasses['SMALL_CALIBER'],
    [`WEAPON_REVOLVER_CATTLEMAN_MEXICAN`] = Config.WeaponClasses['SMALL_CALIBER'],
    [`WEAPON_REVOLVER_CATTLEMAN_PIG`] = Config.WeaponClasses['SMALL_CALIBER'],
    [`WEAPON_PISTOL_MAUSER`] = Config.WeaponClasses['SMALL_CALIBER'],
    [`WEAPON_PISTOL_MAUSER_DRUNK`] = Config.WeaponClasses['SMALL_CALIBER'],
    [`WEAPON_PISTOL_SEMIAUTO`] = Config.WeaponClasses['SMALL_CALIBER'],

    -- Medium Caliber
    [`WEAPON_RIFLE_SPRINGFIELD`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_REPEATER_EVANS`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_REPEATER_WINCHESTER`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_REPEATER_CARBINE_SADIE`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_REPEATER_CARBINE`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_REPEATER_WINCHESTER_JOHN`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_PISTOL_M1899`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_PISTOL_VOLCANIC`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_REVOLVER_SCHOFIELD`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_REVOLVER_LEMAT`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_RIFLE_VARMINT`] = Config.WeaponClasses['MEDIUM_CALIBER'],

    -- High Caliber
    [`WEAPON_SNIPERRIFLE_CARCANO`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_SNIPERRIFLE_ROLLINGBLOCK_EXOTIC`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_SNIPERRIFLE_ROLLINGBLOCK`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_RIFLE_BOLTACTION`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_RIFLE_BOLTACTION_BILL`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_SNIPERRIFLE_ROLLINGBLOCK_LENNY`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_RIFLE_ELEPHANT`] = Config.WeaponClasses['HIGH_CALIBER'],

    -- Shotguns
    [`WEAPON_SHOTGUN_DOUBLEBARREL_UNCLE`] = Config.WeaponClasses['SHOTGUN'],
    [`WEAPON_SHOTGUN_DOUBLEBARREL_EXOTIC`] = Config.WeaponClasses['SHOTGUN'],
    [`WEAPON_SHOTGUN_PUMP`] = Config.WeaponClasses['SHOTGUN'],
    [`WEAPON_SHOTGUN_REPEATING`] = Config.WeaponClasses['SHOTGUN'],
    [`WEAPON_SHOTGUN_SAWEDOFF_CHARLES`] = Config.WeaponClasses['SHOTGUN'],
    [`WEAPON_SHOTGUN_SAWEDOFF`] = Config.WeaponClasses['SHOTGUN'],
    [`WEAPON_SHOTGUN_SEMIAUTO_HOSEA`] = Config.WeaponClasses['SHOTGUN'],
    [`WEAPON_SHOTGUN_SEMIAUTO`] = Config.WeaponClasses['SHOTGUN'],
    [`WEAPON_SHOTGUN_DOUBLEBARREL`] = Config.WeaponClasses['SHOTGUN'],

    -- Wildlife
    [`WEAPON_WOLF_MEDIUM`] = Config.WeaponClasses['WILDLIFE'],
    [`WEAPON_HORSE`] = Config.WeaponClasses['WILDLIFE'],
    [`WEAPON_COUGAR`] = Config.WeaponClasses['WILDLIFE'],
    [`WEAPON_FOX`] = Config.WeaponClasses['WILDLIFE'],
    [`WEAPON_WOLF`] = Config.WeaponClasses['WILDLIFE'],
    [`WEAPON_ALLIGATOR`] = Config.WeaponClasses['WILDLIFE'],
    [`WEAPON_SNAKE`] = Config.WeaponClasses['WILDLIFE'],
    [`WEAPON_BADGER`] = Config.WeaponClasses['WILDLIFE'],
    [`WEAPON_DEER`] = Config.WeaponClasses['WILDLIFE'],
    [`WEAPON_COYOTE`] = Config.WeaponClasses['WILDLIFE'],
    [`WEAPON_BEAR`] = Config.WeaponClasses['WILDLIFE'],
    [`WEAPON_MUSKRAT`] = Config.WeaponClasses['WILDLIFE'],
    [`WEAPON_WOLF_SMALL`] = Config.WeaponClasses['WILDLIFE'],
    [`WEAPON_RACCOON`] = Config.WeaponClasses['WILDLIFE'],
    [`WEAPON_ANIMAL`] = Config.WeaponClasses['WILDLIFE'],

    -- Cutting Weapons
    [`WEAPON_THROWN_TOMAHAWK`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_MELEE_MACHETE`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_MELEE_CLEAVER`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_MELEE_HATCHET_HUNTER_RUSTED`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_MELEE_HATCHET_HEWING`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_MELEE_HATCHET_DOUBLE_BIT_RUSTED`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_MELEE_HATCHET_DOUBLE_BIT`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_MELEE_HATCHET_HUNTER`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_MELEE_HATCHET_VIKING`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_MELEE_ANCIENT_HATCHET`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_MELEE_HATCHET`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_MELEE_BROKEN_SWORD`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_MELEE_KNIFE`] = Config.WeaponClasses['CUTTING'],

    -- Other
    [`WEAPON_RAMMED_BY_CAR`] = Config.WeaponClasses['OTHER'],
    [`WEAPON_RUN_OVER_BY_CAR`] = Config.WeaponClasses['OTHER'],
    [`WEAPON_UNARMED`] = Config.WeaponClasses['LIGHT_IMPACT'],
    [`WEAPON_MELEE_HAMMER`] = Config.WeaponClasses['HEAVY_IMPACT'],
    [`WEAPON_DYNAMITE`] = Config.WeaponClasses['FIRE'],
    [`WEAPON_MOLOTOV`] = Config.WeaponClasses['FIRE'],
    [`WEAPON_FIRE`] = Config.WeaponClasses['FIRE'],
    [`WEAPON_FALL`] = Config.WeaponClasses['FALL'],
    [`WEAPON_THROWN_MOLOTOV`] = Config.WeaponClasses['EXPLOSIVE'],
    [`WEAPON_THROWN_DYNAMITE`] = Config.WeaponClasses['EXPLOSIVE'],
    [`WEAPON_EXPLOSION`] = Config.WeaponClasses['EXPLOSIVE'],
    [`WEAPON_DROWNING_IN_VEHICLE`] = Config.WeaponClasses['SUFFOCATING'],
    [`WEAPON_DROWNING`] = Config.WeaponClasses['SUFFOCATING'],
}

Config.BodyParts = {
    ['HEAD'] = { label = 'in the head', causeLimp = false, isDamaged = false, severity = 0 },
    ['NECK'] = { label = 'in the neck', causeLimp = false, isDamaged = false, severity = 0 },
    ['SPINE'] = { label = 'in the back', causeLimp = true, isDamaged = false, severity = 0 },
    ['UPPER_BODY'] = { label = 'on the upper body', causeLimp = false, isDamaged = false, severity = 0 },
    ['LOWER_BODY'] = { label = 'on the lower body', causeLimp = true, isDamaged = false, severity = 0 },
    ['LARM'] = { label = 'on the left arm', causeLimp = false, isDamaged = false, severity = 0 },
    ['LHAND'] = { label = 'on the right arm', causeLimp = false, isDamaged = false, severity = 0 },
    ['LFINGER'] = { label = 'in the fingers on your left hand', causeLimp = false, isDamaged = false, severity = 0 },
    ['LLEG'] = { label = 'in the left leg', causeLimp = true, isDamaged = false, severity = 0 },
    ['LFOOT'] = { label = 'in the left foot', causeLimp = true, isDamaged = false, severity = 0 },
    ['RARM'] = { label = 'in the right arm', causeLimp = false, isDamaged = false, severity = 0 },
    ['RHAND'] = { label = 'in the right hand', causeLimp = false, isDamaged = false, severity = 0 },
    ['RFINGER'] = { label = 'in the fingers of the right hand', causeLimp = false, isDamaged = false, severity = 0 },
    ['RLEG'] = { label = 'in the right leg', causeLimp = true, isDamaged = false, severity = 0 },
    ['RFOOT'] = { label = 'in the right foot', causeLimp = true, isDamaged = false, severity = 0 },
    
}

Config.parts = { -- don't touch if you dont know what are you doing
    [0]     = 'NONE',
    [21030] = 'HEAD',
    [21031] = 'HEAD',
    [14283] = 'NECK',
    [14411] = 'SPINE',
    [11569] = 'SPINE',
    [23553] = 'SPINE',
    [14410] = 'SPINE',
    [14412] = 'SPINE',
    [14413] = 'SPINE',
    [14414] = 'SPINE',
    [54802] = 'UPPER_BODY',
    [64729] = 'UPPER_BODY',
    [30226] = 'LOWER_BODY',
    [56200] = 'LOWER_BODY',
    [37873] = 'LARM',
    [53675] = 'LARM',
    [34606] = 'LHAND',
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
    [65478] = 'LLEG', 
    [55120] = 'LLEG',
    [53081] = 'LFOOT',
    [45454] = 'LFOOT',
    [46065] = 'RARM',
    [54187] = 'RARM',
    [22798] = 'RHAND',
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
    [6884] = 'RLEG',
    [43312] = 'RLEG',
    [41273] = 'RFOOT',
    [33646] = 'RFOOT',
}
