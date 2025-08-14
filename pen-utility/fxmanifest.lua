fx_version 'bodacious'
game 'gta5'

author 'pen'
version '1.0.0'

lua54 'yes'

shared_script '@ox_lib/init.lua'

shared_script 'sh_*.lua'
server_script 'sv_*.lua'
client_script 'cl_*.lua'

escrow_ignore 'sv_config.lua'

dependencies {
    'ox_lib'
}