-- Ejemplos de uso del sistema de diálogos

-- 1. Diálogo simple básico
local simpleDialog = {
    id = "welcome_dialog",
    speaker = "NPC Bienvenida",
    text = "¡Bienvenido al servidor! ¿En qué puedo ayudarte?",
    animation = {
        type = "common",
        dict = "anim@amb@clubhouse@",
        anim = "bouncer_a_chill",
        flag = 49,
        duration = 5000
    },
    options = {
        {
            label = "Ver reglas",
            callback = function(data)
                print("Usuario quiere ver las reglas")
                TriggerEvent('chat:addMessage', { args = { "^3Reglas del servidor..." } })
            end,
            close = true
        },
        {
            label = "Cerrar",
            close = true
        }
    }
}

-- 2. Cadena de diálogos con branching
local dialogChain = {
    ["start"] = {
        speaker = "Misterioso",
        text = "¡Hola viajero! ¿Buscas aventura?",
        animation = {
            type = "common",
            dict = "gestures@f@standing@casual",
            anim = "gesture_point"
        },
        options = {
            { label = "Sí, estoy listo", next = "quest_start" },
            { label = "No estoy seguro", next = "hesitate" },
            { label = "Vete", close = true }
        }
    },
    ["quest_start"] = {
        speaker = "Misterioso",
        text = "¡Excelente! Tu primera misión es investigar el abandonado...",
        animation = {
            type = "common",
            dict = "anim@mp_facial_tourist",
            anim = "look_around_left",
            facial = "mood_suspicious"
        },
        options = {
            { label = "Entendido", next = "mission_brief" },
            { label = "¿Demasiado peligroso?", close = true }
        }
    },
    ["hesitate"] = {
        speaker = "Misterioso",
        text = "El valor se encuentra superando el miedo...",
        animation = {
            type = "common",
            dict = "gestures@f@standing@casual",
            anim = "gesture_shrug_hard"
        },
        options = {
            { label = "Vale, empezaré", next = "quest_start" },
            { label = "Prefiero quedarme", close = true }
        }
    },
    ["mission_brief"] = {
        speaker = "Misterioso",
        text = "Busca información en el área antigua y regresa aquí.",
        options = {
            { 
                label = "Acepto la misión",
                callback = function(data)
                    TriggerEvent('startQuest', 'first_mission')
                end,
                close = true
            },
            { label = "Necesito más información", close = true }
        }
    }
}

-- 3. Diálogo con condiciones y metadata
local conditionalDialog = {
    id = "merchant_dialog",
    speaker = "Mercader",
    text = "¡Hola! Tengo artículos especiales para miembros VIP.",
    metadata = {
        vipRequired = true,
        playerLevel = 10
    },
    conditions = function(player)
        local isVip = GetResourceKvpInt("player_vip") == 1
        local level = GetResourceKvpInt("player_level")
        return isVip and level >= 10
    end,
    options = {
        { 
            label = "Ver artículos VIP",
            callback = function(data)
                TriggerEvent('openVipShop', data.metadata)
            end
        },
        { label = "Cerrar", close = true }
    }
}

-- 4. Diálogo con animación facial
local facialDialog = {
    id = "emotional_dialog",
    speaker = "NPC Emocional",
    text = "Estoy muy feliz de verte aquí...",
    animation = {
        type = "facial",
        facial = "mood_happy",
        dict = "facials@gen_male@variations@happy",
        duration = 4000
    },
    options = {
        { label = "¡Yo también!", next = "happy_response" },
        { label = "Cerrar", close = true }
    }
}

-- 5. NPC con múltiples diálogos
local npcDialogs = {
    ["greeting"] = {
        speaker = "NPC Ciudadano",
        text = "¡Buenos días! ¿Cómo estás hoy?",
        animation = {
            type = "common",
            dict = "friends@frj@ig_1",
            anim = "wave_a"
        },
        options = {
            { label = "Muy bien, gracias", next = "conversation" },
            { label = "¿Sabes dónde está...?", next = "directions" },
            { label = "Adiós", close = true }
        }
    },
    ["conversation"] = {
        speaker = "NPC Ciudadano",
        text = "¡Qué bueno escuchar eso! Hace un día hermoso, ¿no?",
        options = {
            { label = "Sí, el clima está perfecto", next = "weather_chat" },
            { label = "Bueno, me voy", close = true }
        }
    },
    ["directions"] = {
        speaker = "NPC Ciudadano",
        text = "¿Qué estás buscando? Quizás pueda ayudarte.",
        options = {
            { label = "Busco el hospital", callback = function()
                TriggerEvent('chat:addMessage', { args = { "^3El hospital está hacia el norte." } })
            end, close = true },
            { label = "Busco la comisaría", callback = function()
                TriggerEvent('chat:addMessage', { args = { "^3La comisaría está hacia el este." } })
            end, close = true }
        }
    },
    ["weather_chat"] = {
        speaker = "NPC Ciudadano",
        text = "Definitivamente. ¡Disfruta tu día!",
        options = {
            { label = "¡Gracias, tú también!", close = true }
        }
    }
}

-- Evento de ejemplo para interacción con NPC
AddEventHandler('playerSpawned', function()
    -- Registrar diálogos al spawn
    exports['simple-dialogs']:registerDialogs(dialogChain)
    exports['simple-dialogs']:registerDialogs(npcDialogs)
end)

-- Comando de prueba
RegisterCommand('testdialog', function()
    local ped = PlayerPedId()
    exports['simple-dialogs']:showDialog(simpleDialog, ped)
end)

-- Comando para probar cadena de diálogos
RegisterCommand('testchain', function()
    local ped = PlayerPedId()
    local startDialog = exports['simple-dialogs']:getDialog("start")
    if startDialog then
        exports['simple-dialogs']:showDialog(startDialog, ped)
    end
end)

-- Comando para probar animación de preset
RegisterCommand('testanim', function()
    local ped = PlayerPedId()
    exports['simple-dialogs']:playAnimation(ped, 'WAVE')
end)

-- Comando para probar animación facial
RegisterCommand('testfacial', function()
    local ped = PlayerPedId()
    exports['simple-dialogs']:playFacialAnimation(ped, 'HAPPY')
end)
