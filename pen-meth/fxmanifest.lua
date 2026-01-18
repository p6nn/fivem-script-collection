fx_version 'cerulean'
game 'gta5'

name 'pen-meth'
author 'pen'
description 'meth'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'cl_*.lua'
}

server_scripts {
    'sv_*.lua'
}

dependencies {
    'qbx_core',
    'ox_target',
    'ox_lib'
}