
fx_version 'cerulean'
game 'gta5'

name 'pen-global-dui'
author 'pen'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'shared/config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/callbacks.lua'
}

client_scripts {
    'client/state.lua',
    'client/dui.lua',
    'client/targets.lua',
    'client/menus.lua',
    'client/spawn.lua',
    'client/placement.lua'
}