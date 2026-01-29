fx_version 'cerulean'
game 'gta5'

author 'JericoFX'
description 'Sistema de diálogos minimalista para FiveM'
version '1.1.0'

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
    'client/tasks.lua',
    'client/main.lua',
    'client/anims.lua',
    'client/exports.lua'
}

server_script 'server/exports.lua'

files {
    'nui/index.html',
    'nui/css/style.css',
    'nui/js/main.js'
}

dependencies {}
