const visitOutcomeToDisplayClass = new Map([
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

export {
    visitOutcomeToDisplayClass,
    visitStatusToDisplayClass
}