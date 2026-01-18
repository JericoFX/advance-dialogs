let currentDialog = null;
let activeDialogId = null;

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

    if (dialogData.id) {
        activeDialogId = dialogData.id;
    }

    $('#speaker').text(sanitizeHTML(dialogData.speaker || ''));
    $('#dialog-text').text(sanitizeHTML(dialogData.text || ''));

    $('#options').empty();

    if (dialogData.options && Array.isArray(dialogData.options)) {
        dialogData.options.forEach((option, index) => {
            const optionElement = $('<div></div>')
                .addClass('option')
                .attr('data-index', index);

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
                selectOption(index);
            });

            $('#options').append(optionElement);
        });
    }

    $('#dialog-container').removeClass('hidden');

    console.log('[SimpleDialogs] Dialog shown:', dialogData);
}

function hideDialog() {
    $('#dialog-container').addClass('hidden');
    
    currentDialog = null;
    activeDialogId = null;
    
    $('#options').empty();
    $('#speaker').text('');
    $('#dialog-text').text('');
    
    console.log('[SimpleDialogs] Dialog hidden');
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
        console.log('[SimpleDialogs] Option selected response:', data);
    })
    .catch(error => {
        console.error('[SimpleDialogs] Error selecting option:', error);
    });
}

function getCurrentDialog() {
    return currentDialog;
}

function getActiveDialogId() {
    return activeDialogId;
}
