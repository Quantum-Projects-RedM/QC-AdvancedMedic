fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
author 'Quantum Projects Community'
description 'QC-AdvancedMedic - Advanced Medical System for RedM | Dev: Artmines'
quantum_github 'https://github.com/Quantum-Projects-RedM/QC-AdvancedMedic'
use_experimental_fxv2_oal 'yes'
version '0.3.1'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'ConfigMissions.lua',
}

files {
    'locales/*.json',
    'ui/build/index.html',
    'ui/build/static/**/*'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',

    -- Core (kept for useable items and initialization)
    'server/server.lua',          -- Main entry point & useable items
    'server/database.lua',        -- Database integration layer

    -- Helpers (load before systems)
    'server/helpers/validators.lua',      -- NEW: Consolidated validation (IsMedicJob defined once)
    'server/helpers/notifications.lua',   -- NEW: Centralized notifications

    -- Systems (treatments includes server-authoritative validation)
    'server/systems/wounds.lua',          -- NEW: Wound data operations
    'server/systems/treatments.lua',      -- NEW: Treatment system with auth (distance, rate limit, item checks)
    'server/systems/infections.lua',      -- NEW: Infection data operations

    -- Handlers
    'server/handlers/callbacks.lua',      -- NEW: Callback router system
    'server/handlers/events.lua',         -- NEW: Network event handlers
    'server/handlers/commands.lua',       -- NEW: Admin commands (consolidated /revive+/clearwounds)

    -- Misc
    'server/sv_bag.lua',          -- Medical bag server logic
    'server/versionchecker.lua',  -- Version checking
}

client_scripts {
    -- Utilities (load first)
    'client/utils/callbacks.lua',        -- Server-authoritative callback system
    'client/utils/medical_helpers.lua',  -- NEW: Utility functions (replaces client_shared.lua)

    -- Main entry point
    'client/main.lua',                   -- NEW: initialization

    -- Core medical systems (NEW CONSOLIDATED STRUCTURE)
    'client/medical/core_medical.lua',   -- NEW: Consolidated wound + treatment + healing
    'client/medical/infection_system.lua', -- Infection progression (refactored)

    -- Job systems
    'client/job/medic_job.lua',          -- Job mechanics (duty, revive, treat)
    'client/job/medic_missions.lua',     -- Mission system (ConfigMissions integration)

    -- Environmental
    'client/environmental/envanim_system.lua', -- Environmental & animal attacks

    -- Crafting
    'client/crafting/medic_bag.lua',     -- Medical bag system

    -- Legacy (TEMP: Death/revive/UI logic - to be refactored)
    'client/client.lua',                 -- Core client functionality (death, revive, UI)
}

dependencies {
    'rsg-core',
    'rsg-bossmenu',
    'ox_lib'
}

lua54 'yes'
ui_page 'ui/build/index.html'