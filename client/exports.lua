--[[
    Client Exports
    
    Consolidated exports for Advance Dialog system.
    All exports are registered here for easy access from other resources.
]]

-- ============================================
-- MAIN DIALOG FUNCTIONS
-- ============================================

exports('showDialog', showDialog)
exports('closeDialog', closeDialog)
exports('getDialogState', getDialogState)
exports('isDialogOpen', getDialogState)
exports('stopAnimations', stopCurrentAnimations)
exports('setActivePed', setActivePed)
exports('getActivePed', getActivePed)
exports('createPedAndOpen', createPedAndOpen)

-- ============================================
-- NEW SYSTEM V2: Dialog Registry
-- ============================================

exports('registerDialog', registerDialog)
exports('openDialog', openDialog)
exports('goBack', goBack)
exports('clearHistory', clearHistory)
exports('getHistory', getHistory)
exports('getActiveEntity', getActiveEntity)
exports('getActiveDialogId', getActiveDialogId)
exports('getRegisteredDialog', getRegisteredDialog)

-- ============================================
-- NEW SYSTEM V2: Task API
-- ============================================

exports('TaskAPI', TaskAPI)

-- ============================================
-- ANIMATION FUNCTIONS
-- ============================================

exports('playAnimation', playAnimation)
exports('playFacialAnimation', playFacialAnimation)
exports('getPresetAnimations', getPresetAnimations)
exports('getPresetFacials', getPresetFacials)
