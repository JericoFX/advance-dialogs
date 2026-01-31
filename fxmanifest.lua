fx_version 'cerulean'
game 'gta5'

author 'JericoFX'
description 'Modern dialog system for FiveM with clean API'
version '2.0.0'

ui_page 'nui/index.html'

shared_scripts {
    'shared/enums.lua',
    'locales/*.lua'
}

client_scripts {
    'config.lua',
    'client/utils.lua',
    'client/camera.lua',
    'client/ped.lua',
    'client/dialog_registry.lua',
    'client/task_api.lua',
    'client/main.lua',
    'client/anims.lua',
    'client/exports.lua'
}

server_scripts {
    'server/config_database.lua',
    'server/database.lua',
    'server/events.lua',
    'server/exports.lua'
}

files {
    'nui/index.html',
    'nui/css/style.css',
    'nui/js/main.js',
    'docs/database_setup.sql'
}

dependencies {
    'oxmysql'
}
