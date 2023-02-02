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
