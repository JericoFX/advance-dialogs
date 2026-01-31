let currentDialog = null;
let activeDialogId = null;
let progressTimer = null;

function sanitizeHTML(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

$(document).ready(function() {
    window.addEventListener('message', function(event) {
        const data = event.data;
        
        if (data.action === 'showDialog') {
            showDialog(data.data);
        } else if (data.action === 'closeDialog') {
            hideDialog();
        } else if (data.action === 'progressStart') {
            startProgress(data.data);
        } else if (data.action === 'progressEnd') {
            endProgress();
        }
    });
    
    $(document).on('keydown', function(e) {
        if (e.key === 'Escape' && activeDialogId !== null) {
            selectOption(-1);
        }
    });
});

function showDialog(dialogData) {
    currentDialog = dialogData;

    if (dialogData.id !== undefined && dialogData.id !== null) {
        activeDialogId = dialogData.id;
    }

    $('#speaker').text(sanitizeHTML(dialogData.speaker || ''));
    $('#dialog-text').text(sanitizeHTML(dialogData.text || ''));

    $('#options').empty();

    // Add "Back" button if showBack is true
    if (dialogData.showBack) {
        const backElement = $('<div></div>')
            .addClass('option back-button')
            .attr('data-action', 'back');

        const backLabel = $('<span></span>')
            .addClass('label')
            .text('← Atrás');

        backElement.append(backLabel);

        backElement.on('click', function() {
            selectAction('back');
        });

        $('#options').append(backElement);
    }

    if (dialogData.options && Array.isArray(dialogData.options)) {
        dialogData.options.forEach((option, index) => {
            const optionElement = $('<div></div>')
                .addClass('option')
                .attr('data-index', index);

            if (option.disabled) {
                optionElement.addClass('disabled');
            }

            if (option.icon) {
                const icon = $('<span></span>')
                    .addClass('icon')
                    .text(sanitizeHTML(option.icon));
                optionElement.append(icon);
            }

            const label = $('<span></span>')
                .addClass('label')
                .text(sanitizeHTML(option.label || ''));

            optionElement.append(label);

            if (option.description) {
                const description = $('<span></span>')
                    .addClass('description')
                    .text(sanitizeHTML(option.description));

                optionElement.append(description);
            }

            optionElement.on('click', function() {
                if (option.disabled) {
                    return;
                }
                selectOption(index);
            });

            $('#options').append(optionElement);
        });
    }

    $('#dialog-container').removeClass('hidden');

    console.log('[AdvanceDialog] Dialog shown:', dialogData);
}

function hideDialog() {
    $('#dialog-container').addClass('hidden');
    
    currentDialog = null;
    activeDialogId = null;
    
    $('#options').empty();
    $('#speaker').text('');
    $('#dialog-text').text('');
    
    console.log('[AdvanceDialog] Dialog hidden');
}

function startProgress(progressData) {
    const label = (progressData && progressData.label) ? progressData.label : 'Working...';
    const duration = (progressData && progressData.duration) ? progressData.duration : 1000;

    if (progressTimer) {
        clearTimeout(progressTimer);
        progressTimer = null;
    }

    $('#progress-label').text(label);
    $('#progress-fill').css({ width: '0%' });
    $('#progress-container').removeClass('hidden');

    setTimeout(() => {
        $('#progress-fill').css({ transition: `width ${duration}ms linear`, width: '100%' });
    }, 10);

    progressTimer = setTimeout(() => {
        endProgress();
    }, duration + 50);
}

function endProgress() {
    if (progressTimer) {
        clearTimeout(progressTimer);
        progressTimer = null;
    }

    $('#progress-container').addClass('hidden');
    $('#progress-label').text('');
    $('#progress-fill').css({ width: '0%', transition: 'none' });
}

function selectOption(index) {
    if (index === -1) {
        hideDialog();
    }
    
    fetch(`https://${GetParentResourceName()}/selectOption`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify({
            index: index,
            dialogId: activeDialogId
        })
    })
    .then(response => response.text())
    .then(data => {
        console.log('[AdvanceDialog] Option selected response:', data);
    })
    .catch(error => {
        console.error('[AdvanceDialog] Error selecting option:', error);
    });
}

function selectAction(action) {
    if (!action) return;
    
    if (action === 'back') {
        console.log('[AdvanceDialog] Back action triggered');
    }
    
    fetch(`https://${GetParentResourceName()}/selectOption`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify({
            action: action,
            dialogId: activeDialogId
        })
    })
    .then(response => response.text())
    .then(data => {
        console.log('[AdvanceDialog] Action response:', data);
    })
    .catch(error => {
        console.error('[AdvanceDialog] Error in action:', error);
    });
}

function getCurrentDialog() {
    return currentDialog;
}

function getActiveDialogId() {
    return activeDialogId;
}
