fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
author 'Quantum Projects Community'
description 'Quantum Beekeeping | Dev: Artmines'
quantum_github 'https://github.com/Quantum-Projects-RedM/QC-AdvancedMedic'
use_experimental_fxv2_oal 'yes'
version '0.2.9'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'ConfigMissions.lua',
    'client/client_shared.lua',   -- Load shared functions after config
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',          -- Core server functionality
    'server/sv_bag.lua',          -- Medical bag server logic
    'server/versionchecker.lua',  -- Version checking
    'server/database.lua',        -- NEW: Database integration layer
    'server/medical_events.lua',  -- NEW: Medical system network events
    'server/medical_server.lua'   -- NEW: Medical inspection system with /inspect command
}

client_scripts {
    'client/client.lua',          -- Core client functionality (death, revive, UI)
    'client/bag.lua',             -- Medical bag system
    'client/job_system.lua',      -- Job-related functionality & Missions
    'client/wound_system.lua',    -- Advanced wound detection & tracking
    'client/infection_system.lua', -- Infection progression system
    'client/treatment_system.lua', -- Treatment application system
    'client/wound_healing.lua',   -- Wound healing to scars system
    'client/envanim_system.lua'   -- Environmental & animal attack system
}

dependencies {
    'rsg-core',
    'rsg-bossmenu',
    'ox_lib'
}

files {
    'locales/*.json',
    'ui/build/index.html',
    'ui/build/static/**/*'
}

lua54 'yes'
ui_page 'ui/build/index.html'