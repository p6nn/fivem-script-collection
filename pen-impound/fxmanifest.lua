fx_version 'cerulean'
game 'gta5'

description 'impound with mantine ui wip'
version '1.0.0'
author 'pen'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql',
    'ox_target'
}

lua54 'yes'