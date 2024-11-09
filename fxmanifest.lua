fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-medic'
version '2.0.3'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/client.lua',
    'client/job.lua',
    'client/wounds.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua',
}

files {
    'locales/*.json'
}

dependencies {
    'rsg-core',
    'rsg-bossmenu',
    'ox_lib'
}

lua54 'yes'
