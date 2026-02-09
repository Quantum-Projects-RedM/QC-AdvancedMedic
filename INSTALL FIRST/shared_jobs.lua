    -- =============================================
    -- QC-AdvancedMedic - Medical Profession Jobs
    -- Add these to rsg-core/shared/jobs.lua
    -- Replace the default 'medic' job with these
    -- 1890s-era physician ranks & titles
    -- =============================================

    -- Valentine Physician's Office
    valmedic = {
        name = 'valmedic',
        label = 'Valentine Physician',
        type = 'medic',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Orderly',              payment = 5 },   -- Hospital attendant, cleans and assists
            ['1'] = { name = 'Nurse',                 payment = 15 },  -- Basic patient care and wound dressing
            ['2'] = { name = 'Apothecary',            payment = 25 },  -- Prepares medicines and tinctures
            ['3'] = { name = 'General Practitioner',  payment = 40 },  -- Licensed to diagnose and treat
            ['4'] = { name = 'Physician',             payment = 60 },  -- Experienced doctor, full medical authority
            ['5'] = { name = 'Surgeon',               payment = 80 },  -- Performs operations and amputations
            ['6'] = { name = 'Chief of Medicine',     isboss = true, payment = 100 }, -- Runs the practice
        },
    },

    -- Saint Denis General Hospital
    sdmedic = {
        name = 'sdmedic',
        label = 'Saint Denis Hospital',
        type = 'medic',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Ward Attendant',        payment = 5 },   -- Maintains the ward, assists patients
            ['1'] = { name = 'Nurse',                 payment = 15 },  -- Patient care and medication administration
            ['2'] = { name = 'Pharmacist',            payment = 25 },  -- Dispenses drugs and compounds
            ['3'] = { name = 'Resident Physician',    payment = 40 },  -- Doctor in training under supervision
            ['4'] = { name = 'Attending Physician',   payment = 60 },  -- Full practicing doctor
            ['5'] = { name = 'Surgeon',               payment = 80 },  -- Surgical specialist
            ['6'] = { name = 'Head Surgeon',          payment = 95 },  -- Senior surgical authority
            ['7'] = { name = 'Hospital Director',     isboss = true, payment = 120 }, -- Runs the hospital
        },
    },

    -- Blackwater County Infirmary
    bwmedic = {
        name = 'bwmedic',
        label = 'Blackwater Infirmary',
        type = 'medic',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Orderly',              payment = 5 },
            ['1'] = { name = 'Nurse',                 payment = 15 },
            ['2'] = { name = 'Apothecary',            payment = 25 },
            ['3'] = { name = 'General Practitioner',  payment = 40 },
            ['4'] = { name = 'Physician',             payment = 60 },
            ['5'] = { name = 'Surgeon',               payment = 80 },
            ['6'] = { name = 'Chief of Medicine',     isboss = true, payment = 100 },
        },
    },

    -- Rhodes Township Doctor
    rhmedic = {
        name = 'rhmedic',
        label = 'Rhodes Practitioner',
        type = 'medic',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Orderly',              payment = 5 },
            ['1'] = { name = 'Nurse',                 payment = 12 },
            ['2'] = { name = 'Apothecary',            payment = 20 },
            ['3'] = { name = 'General Practitioner',  payment = 35 },
            ['4'] = { name = 'Physician',             payment = 55 },
            ['5'] = { name = 'Surgeon',               payment = 75 },
            ['6'] = { name = 'Chief of Medicine',     isboss = true, payment = 90 },
        },
    },

    -- Strawberry Frontier Doctor
    sbmedic = {
        name = 'sbmedic',
        label = 'Strawberry Doctor',
        type = 'medic',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Orderly',              payment = 5 },
            ['1'] = { name = 'Nurse',                 payment = 12 },
            ['2'] = { name = 'Apothecary',            payment = 20 },
            ['3'] = { name = 'General Practitioner',  payment = 35 },
            ['4'] = { name = 'Physician',             payment = 55 },
            ['5'] = { name = 'Surgeon',               payment = 75 },
            ['6'] = { name = 'Chief of Medicine',     isboss = true, payment = 90 },
        },
    },
