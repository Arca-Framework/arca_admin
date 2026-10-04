fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'arca_admin'
author 'Arca'
description 'Admin menu for the Arca framework'
version '0.1.0'

shared_scripts {
    '@arca_core/shared/import.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
    'client/tools.lua',
    'client/world.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/bans.lua',
    'server/world.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/logo.png',
}

dependencies {
    'oxmysql',
    'arca_core',
}
