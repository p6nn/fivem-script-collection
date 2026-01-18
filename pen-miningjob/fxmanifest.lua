fx_version 'cerulean'
game 'gta5'

name 'pen-miningjob'
author 'pen'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

dependencies {
    'qbx_core',
    'ox_inventory',
    'ox_target',
    'ox_lib'
}

lua54 'yes'