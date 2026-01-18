DialogEnums = {
    AnimationType = {
        COMMON = "common",
        FACIAL = "facial",
        GESTURE = "gesture",
        PHONE = "phone"
    },
    
    DialogState = {
        OPEN = "open",
        CLOSED = "closed",
        TRANSITION = "transition"
    },
    
    AnimationFlag = {
        NORMAL = 0,
        STOP_LAST_FRAME = 1,
        UPPER_BODY = 49,
        LOOP = 1,
        HOLD = 4,
        INTERRUPTIBLE = 16
    },
    
    FacialExpression = {
        MOOD_NEUTRAL = "mood_neutral",
        MOOD_HAPPY = "mood_happy",
        MOOD_ANGRY = "mood_angry",
        MOOD_SAD = "mood_sad",
        MOOD_SURPRISED = "mood_surprised",
        MOOD_SUSPICIOUS = "mood_suspicious"
    },
    
    EventType = {
        DIALOG_OPEN = "simple-dialogs:open",
        DIALOG_CLOSE = "simple-dialogs:close",
        OPTION_SELECTED = "simple-dialogs:optionSelected",
        ANIMATION_START = "simple-dialogs:animationStart",
        ANIMATION_END = "simple-dialogs:animationEnd"
    }
}

return DialogEnums
