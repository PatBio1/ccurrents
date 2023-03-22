import { NavigationMixin } from 'lightning/navigation';

/**
 * Checks if a given value is null or undefined.
 * @param {any} value The given value to check against null or undefined.
 * @returns {boolean} Whether or not the given value is null or undefined.
 */
export function isNullOrUndef(value) {
    return (value === null || value === undefined);
}

/**
 * Checks if a given value is null, undefined, an empty string, NaN, or an empty object.
 * @param {any} value The given value to check against null, undefined, an empty string, NaN, or an empty object.
 * @returns {boolean} Whether not the given value is null, undefined, an empty string, NaN, or an empty object.
 */
export function isBlank(value) {
    return (
        isNullOrUndef(value) ||
        (typeof value === 'string' && value.trim().length <= 0) ||
        (typeof value === 'number' && isNaN(value)) ||
        (typeof value === 'object' && Object.keys(value).length <= 0)
    );
}

export function isNotBlank(value) {
    return !isBlank(value);
}

export function validateZipCode(event) {
    const pasteShortcut =
        (event.ctrlKey || event.metaKey) && // Windows or Mac
        (event.which === 86 || event.keyCode === 86);

    // If it was not a paste.
    if (event?.key?.length === 1 && !pasteShortcut) {
        const validDigit = /\d/.test(event.key);

        if (!validDigit) {
            // This will allow users to highlight the current value and replace it
            // assuming that what is highlighted is what is currently in the field.
            let currentSelection = window.getSelection()?.toString();

            if (currentSelection) {
                if (!event.target.value.includes(currentSelection)) {
                    event.preventDefault();
                }
            } else {
                event.preventDefault();
            }
        }
    }
}

export function navigateToPage(component, name) {
    component[NavigationMixin.Navigate]({
        type: 'comm__namedPage',
        attributes: {
            name: name
        }
    });
}