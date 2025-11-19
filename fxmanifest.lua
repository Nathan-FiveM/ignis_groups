fx_version 'cerulean'
game 'gta5'

author 'Ignis RP'
description 'Ignis Groups - group system for use with summit_phone'
version '1.0.0'

lua54 'yes'

shared_scripts {
    'shared.lua',
    '@ox_lib/init.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_framework.lua',
    'config.lua',
    'server/server.lua',
    'server/server_queue.lua'
}

client_scripts {
    'client/cl_framework.lua',
    'client/client.lua'
}
