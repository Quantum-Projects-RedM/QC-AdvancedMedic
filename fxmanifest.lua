fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

author 'Quantum Projects Community'
description 'QC-AdvancedMedic - Advanced Medical System for RedM | Dev: Artmines'
quantum_github 'https://github.com/Quantum-Projects-RedM/QC-AdvancedMedic'
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

    'server/server.lua',
    'server/database.lua',

    'server/helpers/validators.lua',
    'server/helpers/notifications.lua',

    'server/systems/wounds.lua',
    'server/systems/treatments.lua',
    'server/systems/infections.lua',

    'server/handlers/callbacks.lua',
    'server/handlers/events.lua',
    'server/handlers/commands.lua',

    'server/sv_bag.lua',
    'server/versionchecker.lua',
}

client_scripts {
    'client/utils/callbacks.lua',
    'client/utils/medical_helpers.lua',
    'client/utils/nui_controller.lua',
    'client/utils/menus.lua',
    'client/utils/useable_items.lua',

    'client/main.lua',

    'client/medical/core_medical.lua',
    'client/medical/infection_system.lua',
    'client/medical/death_system.lua',
    'client/medical/envanim_system.lua',

    'client/job/medic_job.lua',
    'client/job/medic_missions.lua',

    'client/crafting/medic_bag.lua',
}

dependencies {
    'rsg-core',
    'rsg-bossmenu',
    'ox_lib'
}

ui_page 'ui/build/index.html'
