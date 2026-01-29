--[[
    Client Exports
    
    Consolidated exports for the Advance Dialog system.
    All exports are registered here for easy access from other resources.
]]

-- Main dialog functions
exports('showDialog', showDialog)
exports('closeDialog', closeDialog)
exports('getDialogState', getDialogState)
exports('isDialogOpen', getDialogState)
exports('stopAnimations', stopCurrentAnimations)
exports('registerDialogs', registerDialogs)
exports('openDialogById', openDialogById)
exports('setActivePed', setActivePed)
exports('getActivePed', getActivePed)
exports('createPedAndOpen', createPedAndOpen)

-- Task action system (dual registration: global and dialog-specific)
-- Usage:
--   Global: exports['advance-dialog']:registerTaskAction(nil, 'myAction', handler)
--   Dialog-specific: exports['advance-dialog']:registerTaskAction('dialogId', 'myAction', handler)
exports('registerTaskAction', registerTaskAction)

-- Helper functions
exports('openDialogAfterSequence', openDialogAfterSequence)

-- Animation functions
exports('playAnimation', playAnimation)
exports('playFacialAnimation', playFacialAnimation)
exports('getPresetAnimations', getPresetAnimations)
exports('getPresetFacials', getPresetFacials)
