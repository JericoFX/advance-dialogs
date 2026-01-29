Config = {
    -- NUI Configuration
    uiPage = 'nui/index.html',
    closeKey = 27,
    
    -- Animation Settings
    defaultAnimDuration = 3000,
    enableDebug = false,
    
    -- Progress Bar Provider
    -- Options: "ox_lib", "qb-progressbar", "mythic", "none" (NUI fallback)
    progressProvider = "none",
    
    -- Camera Settings
    -- Camera movement smoothing (0.0 = instant, 1.0 = very smooth, default: 0.3)
    cameraLerpFactor = 0.3,
    
    -- Orbit rotation direction: "clockwise" or "counter"
    cameraOrbitDirection = "clockwise",
    
    -- Automatically destroy camera when task sequence ends
    cameraAutoDestroy = true,
    
    -- Task Sequence Settings
    -- Global timeout for task sequences in milliseconds (default: 30 seconds)
    taskSequenceTimeout = 30000,
    
    -- Localization
    Locale = 'en',
    
    -- Animation Libraries to preload
    animationLibrary = {
        "anim@amb@clubhouse@",
        "anim@mp_facial_tourist",
        "missmic2_credits_04",
        "anim@heists@heist_corona@single_team",
        "anim@scripted@payphone_hits@male@"
    }
}
