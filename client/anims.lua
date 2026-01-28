local AnimationPresets = {
    WAVE = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "friends@frj@ig_1",
        anim = "wave_a",
        flag = DialogEnums.AnimationFlag.NORMAL,
        duration = 3000
    },
    
    THUMBS_UP = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "anim@mp_player_intincumbsalute@",
        anim = "salute",
        flag = DialogEnums.AnimationFlag.UPPER_BODY,
        duration = 3000
    },
    
    POINT = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "gestures@f@standing@casual",
        anim = "gesture_point",
        flag = DialogEnums.AnimationFlag.UPPER_BODY,
        duration = 2000
    },
    
    SHRUG = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "gestures@f@standing@casual",
        anim = "gesture_shrug_hard",
        flag = DialogEnums.AnimationFlag.UPPER_BODY,
        duration = 2500
    },
    
    CROSS_ARMS = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "anim@amb@clubhouse@",
        anim = "bouncer_a_chill",
        flag = DialogEnums.AnimationFlag.LOOP,
        duration = -1
    },
    
    HANDS_UP = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "missminuteman_1ig_2",
        anim = "handsup_base",
        flag = DialogEnums.AnimationFlag.HOLD,
        duration = -1
    },
    
    THINKING = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "anim@amb@casino@amb@casino_gamers@gamers@male@001b@male_a@standing@casino_gaming@standing@base",
        anim = "standing_thinking_01_base",
        flag = DialogEnums.AnimationFlag.LOOP,
        duration = -1
    },
    
    WELCOME = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "anim@mp_player_intwelcome@",
        anim = "welcome",
        flag = DialogEnums.AnimationFlag.NORMAL,
        duration = 4000
    },
    
    BYE = {
        type = DialogEnums.AnimationType.COMMON,
        dict = "special_ped@jane@bail_bond_office@wait@loop@",
        anim = "greeting_loop_wanda",
        flag = DialogEnums.AnimationFlag.NORMAL,
        duration = 3000
    }
}

local FacialPresets = {
    HAPPY = {
        type = DialogEnums.AnimationType.FACIAL,
        facial = DialogEnums.FacialExpression.MOOD_HAPPY,
        dict = "facials@gen_male@variations@happy"
    },
    
    ANGRY = {
        type = DialogEnums.AnimationType.FACIAL,
        facial = DialogEnums.FacialExpression.MOOD_ANGRY,
        dict = "facials@gen_male@variations@angry"
    },
    
    SAD = {
        type = DialogEnums.AnimationType.FACIAL,
        facial = DialogEnums.FacialExpression.MOOD_SAD,
        dict = "facials@gen_male@variations@sad"
    },
    
    SURPRISED = {
        type = DialogEnums.AnimationType.FACIAL,
        facial = DialogEnums.FacialExpression.MOOD_SURPRISED,
        dict = "facials@gen_male@variations@surprised"
    },
    
    NEUTRAL = {
        type = DialogEnums.AnimationType.FACIAL,
        facial = DialogEnums.FacialExpression.MOOD_NEUTRAL,
        dict = "facials@gen_male@variations@neutral"
    },
    
    SUSPICIOUS = {
        type = DialogEnums.AnimationType.FACIAL,
        facial = DialogEnums.FacialExpression.MOOD_SUSPICIOUS,
        dict = "facials@gen_male@variations@suspicious"
    }
}

function playAnimation(ped, presetName, customDuration)
    if not presetName or not AnimationPresets[presetName] then
        return false, "Invalid animation preset"
    end
    
    local preset = AnimationPresets[presetName]
    
    if customDuration then
        preset.duration = customDuration
    end
    
    return exports['advance-dialog']:showDialog({
        id = "advance_dialog_animation",
        animation = preset
    }, ped, true)
end

function playFacialAnimation(ped, presetName, customDuration)
    if not presetName or not FacialPresets[presetName] then
        return false, "Invalid facial preset"
    end
    
    local preset = FacialPresets[presetName]
    
    if customDuration then
        preset.duration = customDuration
    end
    
    return exports['advance-dialog']:showDialog({
        id = "advance_dialog_facial",
        animation = preset
    }, ped, true)
end

function getPresetAnimations()
    return AnimationPresets
end

function getPresetFacials()
    return FacialPresets
end

exports('playAnimation', playAnimation)
exports('playFacialAnimation', playFacialAnimation)
exports('getPresetAnimations', getPresetAnimations)
exports('getPresetFacials', getPresetFacials)
