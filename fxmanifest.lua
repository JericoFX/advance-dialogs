fx_version 'cerulean'
game 'gta5'

author 'JericoFX'
description 'Sistema de diálogos minimalista para FiveM con jQuery'
version '1.0.0'

ui_page 'nui/index.html'

client_script 'config.lua'
client_script 'shared/enums.lua'
client_scripts {
    'client/main.lua',
    'client/anims.lua',
    'client/exports.lua'
}

shared_script 'shared/enums.lua'
server_script 'server/exports.lua'

files {
    'nui/index.html',
    'nui/css/style.css',
    'nui/js/main.js'
}

dependencies {}
