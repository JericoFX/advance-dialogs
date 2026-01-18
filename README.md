# Simple Dialogs - Sistema de Diálogos FiveM

Sistema de diálogos minimalista y flexible para FiveM con soporte para animaciones faciales, corporales y callbacks personalizados.

## Características

- ✅ UI Minimalista con jQuery
- ✅ Animaciones corporales (TaskPlayAnim)
- ✅ Animaciones faciales (PlayFacialAnim)
- ✅ Sistema de branching (cadenas de diálogos)
- ✅ Callbacks personalizables
- ✅ Metadata flexible
- ✅ Condiciones dinámicas
- ✅ Presets de animaciones predefinidas
- ✅ Standalone (sin framework)
- ✅ Exportaciones para otros recursos

## Instalación

1. Copia la carpeta `simple-dialogs` a tu directorio `resources/`
2. Añade `ensure simple-dialogs` a tu `server.cfg`
3. Reinicia el servidor

## Uso Básico

### Estructura de Diálogo

```lua
local dialog = {
    id = "dialog_id",
    speaker = "Nombre NPC",
    text = "Texto del diálogo",
    animation = {
        type = "common",
        dict = "anim@amb@clubhouse@",
        anim = "bouncer_a_chill",
        flag = 49,
        duration = 5000
    },
    options = {
        {
            label = "Opción A",
            next = "dialog_b",
            callback = function(data)
                print("Opción seleccionada:", data.option.label)
            end,
            close = false
        },
        {
            label = "Cerrar",
            close = true
        }
    },
    metadata = {
        customKey = "customValue"
    },
    conditions = function(player)
        return true
    end
}
```

### API Client-side

```lua
-- Mostrar diálogo
exports['simple-dialogs']:showDialog(dialogData, ped)

-- Cerrar diálogo
exports['simple-dialogs']:closeDialog()

-- Verificar estado
local state = exports['simple-dialogs']:getDialogState()
print("Diálogo abierto:", state.isOpen)

-- Reproducir animación preset
exports['simple-dialogs']:playAnimation(ped, 'WAVE')

-- Reproducir animación facial preset
exports['simple-dialogs']:playFacialAnimation(ped, 'HAPPY')

-- Obtener presets disponibles
local anims = exports['simple-dialogs']:getPresetAnimations()
local facials = exports['simple-dialogs']:getPresetFacials()
```

### API Server-side

```lua
-- Registrar múltiples diálogos
exports['simple-dialogs']:registerDialogs({
    ["dialog1"] = { ... },
    ["dialog2"] = { ... }
})

-- Obtener diálogo específico
local dialog = exports['simple-dialogs']:getDialog("dialog_id")

-- Obtener todos los diálogos
local allDialogs = exports['simple-dialogs']:getAllDialogs()
```

## Presets de Animaciones

### Animaciones Corporales
- `WAVE` - Saludar con la mano
- `THUMBS_UP` - Pulgar arriba
- `POINT` - Señalar
- `SHRUG` - Encogerse de hombros
- `CROSS_ARMS` - Brazos cruzados
- `HANDS_UP` - Manos arriba
- `THINKING` - Pensando
- `WELCOME` - Bienvenida
- `BYE` - Despedida

### Animaciones Faciales
- `HAPPY` - Feliz
- `ANGRY` - Enojado
- `SAD` - Triste
- `SURPRISED` - Sorprendido
- `NEUTRAL` - Neutral
- `SUSPICIOUS` - Sospechoso

## Ejemplos

### Diálogo Simple

```lua
local simpleDialog = {
    speaker = "NPC",
    text = "¡Hola! ¿En qué puedo ayudarte?",
    options = {
        { label = "Ver opciones", next = "options_dialog" },
        { label = "Cerrar", close = true }
    }
}

exports['simple-dialogs']:showDialog(simpleDialog, npcPed)
```

### Cadena de Diálogos

```lua
local dialogChain = {
    ["start"] = {
        speaker = "NPC",
        text = "¡Hola!",
        options = {
            { label = "Continuar", next = "mid" }
        }
    },
    ["mid"] = {
        speaker = "NPC",
        text = "¿Cómo estás?",
        options = {
            { label = "Bien", next = "end" }
        }
    },
    ["end"] = {
        speaker = "NPC",
        text = "¡Que tengas buen día!",
        options = { { label = "Adiós", close = true } }
    }
}

exports['simple-dialogs']:registerDialogs(dialogChain)
exports['simple-dialogs']:showDialog(
    exports['simple-dialogs']:getDialog("start"),
    npcPed
)
```

### Diálogo con Animación

```lua
local animatedDialog = {
    speaker = "NPC",
    text = "¡Mira esto!",
    animation = {
        type = "common",
        dict = "gestures@f@standing@casual",
        anim = "gesture_point",
        flag = 49,
        duration = 3000
    },
    options = {
        { label = "¡Impresionante!", close = true }
    }
}
```

### Diálogo con Callback

```lua
local callbackDialog = {
    speaker = "NPC",
    text = "¿Quieres aceptar la misión?",
    options = {
        {
            label = "Sí",
            callback = function(data)
                TriggerEvent('startMission', 'mission_1')
                print("Misión iniciada")
            end,
            close = true
        },
        { label = "No", close = true }
    }
}
```

## Eventos

```lua
-- Diálogo abierto
AddEventHandler('simple-dialogs:open', function(data)
    print("Diálogo abierto:", data.dialog.id)
end)

-- Diálogo cerrado
AddEventHandler('simple-dialogs:close', function(data)
    print("Diálogo cerrado")
end)

-- Opción seleccionada
AddEventHandler('simple-dialogs:optionSelected', function(data)
    print("Opción:", data.option.label)
end)

-- Animación iniciada
AddEventHandler('simple-dialogs:animationStart', function(data)
    print("Animación:", data.animation.anim)
end)

-- Animación finalizada
AddEventHandler('simple-dialogs:animationEnd', function(data)
    print("Animación finalizada")
end)
```

## Comandos de Prueba

```lua
/testdialog - Muestra diálogo simple
/testchain - Muestra cadena de diálogos
/testanim - Prueba animación preset
/testfacial - Prueba animación facial preset
```

## Configuración

```lua
Config = {
    uiPage = 'nui/index.html',
    closeKey = 27,  -- Tecla ESC
    defaultAnimDuration = 3000,
    enableDebug = false,
    animationLibrary = {
        "anim@amb@clubhouse@",
        "anim@mp_facial_tourist"
    }
}
```

## Estructura de Archivos

```
simple-dialogs/
├── fxmanifest.lua
├── config.lua
├── examples.lua
├── client/
│   ├── main.lua
│   ├── anims.lua
│   └── exports.lua
├── server/
│   └── exports.lua
├── shared/
│   └── enums.lua
└── nui/
    ├── index.html
    ├── css/style.css
    └── js/main.js
```

## Notas

- Presiona `ESC` para cerrar el diálogo
- Las animaciones se detienen automáticamente según la duración
- El sistema es standalone, compatible con cualquier framework
- La UI es responsiva y funciona en diferentes resoluciones

## Soporte

Para más ejemplos, revisa el archivo `examples.lua`.

## Licencia

Este recurso es de código abierto y libre para usar en servidores FiveM.
