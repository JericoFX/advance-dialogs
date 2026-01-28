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
        DIALOG_OPEN = "advance-dialog:open",
        DIALOG_CLOSE = "advance-dialog:close",
        OPTION_SELECTED = "advance-dialog:optionSelected",
        ANIMATION_START = "advance-dialog:animationStart",
        ANIMATION_END = "advance-dialog:animationEnd",
        DIALOG_REQUESTED = "advance-dialog:requested",
        DIALOG_DENIED = "advance-dialog:denied"
    }
}

return DialogEnums
