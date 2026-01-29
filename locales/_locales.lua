Locales = {}

function Locale(key, ...)
    local lang = Config and Config.Locale or 'en'
    local translations = Locales[lang] or Locales['en'] or {}
    local translation = translations[key]
    if translation then
        return string.format(translation, ...)
    end
    return key
end

_L = Locale
