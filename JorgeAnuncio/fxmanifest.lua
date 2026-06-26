fx_version 'cerulean'

games { 'gta5' }

lua54 'yes'

shared_scripts {
    'config.lua',
}

client_scripts {
    'locales/en.lua',
    'locales/es.lua',
    'locales/it.lua',
    'locales/de.lua',
    'client/main.lua',
}

server_scripts {
    'locales/en.lua',
    'locales/es.lua',
    'locales/it.lua',
    'locales/de.lua',
    'server/main.lua',
}

ui_page 'ui/build/index.html?hud=true'

files {
    'ui/build/**/*',
}

dependencies {
    'qs-smartphone',
    'oxmysql',
    '/assetpacks',
}

escrow_ignore {
    'client/main.lua',
    'server/main.lua',
}