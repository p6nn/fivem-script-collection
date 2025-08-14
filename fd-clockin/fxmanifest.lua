fx_version 'cerulean'
game 'gta5'

name 'fd-clockin'
author 'pen'
description 'fd-clockin'
version '1.0.0'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua'
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    'client/cl_*.lua'
}

server_scripts {
    'server/sv_*.lua',
    'server/bot/sv_*.js',
    '@mysql-async/lib/MySQL.lua'
}

dependencies {
    'ox_lib',
    'yarn'
}

escrow_ignore {
    'shared/config.lua'
}