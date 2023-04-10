const visitOutcomeToDisplayClass = new Map([
    ["None", "outcome-none"],
    ["No Show", "outcome-no-show"],
    ["Canceled", "outcome-canceled"],
    ["Rescheduled", "outcome-rescheduled"],
    ["Donation", "outcome-donation"]
]);

const visitStatusToDisplayClass = new Map([
    ["New", "status-new"],
    ["Scheduled", "status-scheduled"],
    ["Checked-In", "status-checked-in"],
    ["Complete", "status-completed"]
]);

const minPasswordCharacters = 8;
const maxPasswordCharacters = 16;

export {
    visitOutcomeToDisplayClass,
    visitStatusToDisplayClass,
    minPasswordCharacters,
    maxPasswordCharacters
}