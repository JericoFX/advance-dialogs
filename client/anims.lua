--[[
    Animation Presets and Exports
    
    Provides pre-configured animation and facial expression presets
    for common use cases.
    
    Presets can be used with showDialog() or playAnimation() exports.
]]

---@class AnimationPreset
---@field type string
---@field dict string
---@field anim string
---@field flag number
---@field duration number

---@class FacialPreset
---@field type string
---@field facial string
---@field dict string

---@class AnimationPresetsTable
---@field WAVE AnimationPreset
---@field THUMBS_UP AnimationPreset
---@field POINT AnimationPreset
---@field SHRUG AnimationPreset
---@field CROSS_ARMS AnimationPreset
---@field HANDS_UP AnimationPreset
---@field THINKING AnimationPreset
---@field WELCOME AnimationPreset
---@field BYE AnimationPreset

---@class FacialPresetsTable
---@field HAPPY FacialPreset
---@field ANGRY FacialPreset
---@field SAD FacialPreset
---@field SURPRISED FacialPreset
---@field NEUTRAL FacialPreset
---@field SUSPICIOUS FacialPreset

-- Cache frequently used natives
local GetCurrentResourceNameCached = GetCurrentResourceName
local DoesEntityExistCached = DoesEntityExist

-- ============================================
-- ANIMATION PRESETS
-- ============================================

---@type AnimationPresetsTable
local AnimationPresets = {
    -- Waving gesture
    WAVE = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "friends@frj@ig_1",
        anim = "wave_a",
        flag = DialogEnums.AnimationFlag.NORMAL,
        duration = 3000
    },
    
    -- Thumbs up gesture
    THUMBS_UP = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "anim@mp_player_intincumbsalute@",
        anim = "salute",
        flag = DialogEnums.AnimationFlag.UPPER_BODY,
        duration = 3000
    },
    
    -- Pointing gesture
    POINT = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "gestures@f@standing@casual",
        anim = "gesture_point",
        flag = DialogEnums.AnimationFlag.UPPER_BODY,
        duration = 2000
    },
    
    -- Shrugging gesture
    SHRUG = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "gestures@f@standing@casual",
        anim = "gesture_shrug_hard",
        flag = DialogEnums.AnimationFlag.UPPER_BODY,
        duration = 2500
    },
    
    -- Arms crossed stance
    CROSS_ARMS = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "anim@amb@clubhouse@",
        anim = "bouncer_a_chill",
        flag = DialogEnums.AnimationFlag.LOOP,
        duration = -1
    },
    
    -- Hands up gesture
    HANDS_UP = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "missminuteman_1ig_2",
        anim = "handsup_base",
        flag = DialogEnums.AnimationFlag.HOLD,
        duration = -1
    },
    
    -- Thinking gesture
    THINKING = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "anim@amb@casino@amb@casino_gamers@gamers@male@001b@male_a@standing@casino_gaming@standing@base",
        anim = "standing_thinking_01_base",
        flag = DialogEnums.AnimationFlag.LOOP,
        duration = -1
    },
    
    -- Welcome gesture
    WELCOME = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "anim@mp_player_intwelcome@",
        anim = "welcome",
        flag = DialogEnums.AnimationFlag.NORMAL,
        duration = 4000
    },
    
    -- Goodbye gesture
    BYE = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "special_ped@jane@bail_bond_office@wait@loop@",
        anim = "greeting_loop_wanda",
        flag = DialogEnums.AnimationFlag.NORMAL,
        duration = 3000
    }
}

-- ============================================
-- FACIAL EXPRESSION PRESETS
-- ============================================

---@type FacialPresetsTable
local FacialPresets = {
    -- Happy expression
    HAPPY = {
        type = DialogEnums.AnimationType.FACIAL,
        facial = DialogEnums.FacialExpression.MOOD_HAPPY,
        dict = "facials@gen_male@variations@happy"
    },
    
    -- Angry expression
    ANGRY = {
        type = DialogEnums.AnimationType.FACIAL,
        facial = DialogEnums.FacialExpression.MOOD_ANGRY,
        dict = "facials@gen_male@variations@angry"
    },
    
    -- Sad expression
    SAD = {
        type = DialogEnums.AnimationType.FACIAL,
        facial = DialogEnums.FacialExpression.MOOD_SAD,
        dict = "facials@gen_male@variations@sad"
    },
    
    -- Surprised expression
    SURPRISED = {
        type = DialogEnums.AnimationType.FACIAL,
        facial = DialogEnums.FacialExpression.MOOD_SURPRISED,
        dict = "facials@gen_male@variations@surprised"
    },
    
    -- Neutral expression
    NEUTRAL = {
        type = DialogEnums.AnimationType.FACIAL,
        facial = DialogEnums.FacialExpression.MOOD_NEUTRAL,
        dict = "facials@gen_male@variations@neutral"
    },
    
    -- Suspicious expression
    SUSPICIOUS = {
        type = DialogEnums.AnimationType.FACIAL,
        facial = DialogEnums.FacialExpression.MOOD_SUSPICIOUS,
        dict = "facials@gen_male@variations@suspicious"
    }
}

-- ============================================
-- PUBLIC FUNCTIONS
-- ============================================

---@param ped number
---@param presetName string
---@param customDuration? number
---@return boolean, string?
function playAnimation(ped, presetName, customDuration)
    if not presetName or not AnimationPresets[presetName] then
        return false, "Invalid animation preset"
    end
    
    local preset = AnimationPresets[presetName]
    
    if customDuration then
        preset.duration = customDuration
    end
    
    return exports[GetCurrentResourceNameCached()]:showDialog({
        id = "advance_dialog_animation",
        animation = preset
    }, ped, true)
end

---@param ped number
---@param presetName string
---@param customDuration? number
---@return boolean, string?
function playFacialAnimation(ped, presetName, customDuration)
    if not presetName or not FacialPresets[presetName] then
        return false, "Invalid facial preset"
    end
    
    local preset = FacialPresets[presetName]
    
    if customDuration then
        preset.duration = customDuration
    end
    
    return exports[GetCurrentResourceNameCached()]:showDialog({
        id = "advance_dialog_facial",
        animation = preset
    }, ped, true)
end

---@return AnimationPresetsTable
function getPresetAnimations()
    return AnimationPresets
end

---@return FacialPresetsTable
function getPresetFacials()
    return FacialPresets
end

-- ============================================
-- EXPORTS
-- ============================================

exports('playAnimation', playAnimation)
exports('playFacialAnimation', playFacialAnimation)
exports('getPresetAnimations', getPresetAnimations)
exports('getPresetFacials', getPresetFacials)
