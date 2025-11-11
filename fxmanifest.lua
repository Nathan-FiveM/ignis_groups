fx_version 'cerulean'
game 'gta5'

author 'Ignis RP'
description 'Ignis Groups - group system for use with summit_phone with rep-tablet support'
version '1.0.0'

lua54 'yes'

shared_scripts {
    'shared.lua',
    '@ox_lib/init.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server/server.lua',
    'server/server_queue.lua'   -- add this line
}

client_scripts {
    'client/client.lua'
}
