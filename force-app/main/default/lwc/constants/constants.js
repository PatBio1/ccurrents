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

const suffixOptions = [
    {label: 'Jr', value: 'Jr'},
    {label: 'II', value: 'II'},
    {label: 'Sr', value: 'Sr'},
    {label: 'III', value: 'III'},
    {label: 'IV', value: 'IV'},
    {label: 'V', value: 'V'}
];

const stateOptions = [
    {label: 'AK', value: 'AK'},
    {label: 'AL', value: 'AL'},
    {label: 'AR', value: 'AR'},
    {label: 'AZ', value: 'AZ'},
    {label: 'CA', value: 'CA'},
    {label: 'CO', value: 'CO'},
    {label: 'CT', value: 'CT'},
    {label: 'DC', value: 'DC'},
    {label: 'DE', value: 'DE'},
    {label: 'FL', value: 'FL'},
    {label: 'GA', value: 'GA'},
    {label: 'HI', value: 'HI'},
    {label: 'IA', value: 'IA'},
    {label: 'ID', value: 'ID'},
    {label: 'IL', value: 'IL'},
    {label: 'IN', value: 'IN'},
    {label: 'KS', value: 'KS'},
    {label: 'KY', value: 'KY'},
    {label: 'LA', value: 'LA'},
    {label: 'MA', value: 'MA'},
    {label: 'MD', value: 'MD'},
    {label: 'ME', value: 'ME'},
    {label: 'MI', value: 'MI'},
    {label: 'MN', value: 'MN'},
    {label: 'MO', value: 'MO'},
    {label: 'MS', value: 'MS'},
    {label: 'MT', value: 'MT'},
    {label: 'NC', value: 'NC'},
    {label: 'ND', value: 'ND'},
    {label: 'NE', value: 'NE'},
    {label: 'NH', value: 'NH'},
    {label: 'NJ', value: 'NJ'},
    {label: 'NM', value: 'NM'},
    {label: 'NV', value: 'NV'},
    {label: 'NY', value: 'NY'},
    {label: 'OH', value: 'OH'},
    {label: 'OK', value: 'OK'},
    {label: 'OR', value: 'OR'},
    {label: 'PA', value: 'PA'},
    {label: 'RI', value: 'RI'},
    {label: 'SC', value: 'SC'},
    {label: 'SD', value: 'SD'},
    {label: 'TN', value: 'TN'},
    {label: 'TX', value: 'TX'},
    {label: 'UT', value: 'UT'},
    {label: 'VA', value: 'VA'},
    {label: 'VT', value: 'VT'},
    {label: 'WA', value: 'WA'},
    {label: 'WI', value: 'WI'},
    {label: 'WV', value: 'WV'},
    {label: 'WY', value: 'WY'}
];


export {
    visitOutcomeToDisplayClass,
    visitStatusToDisplayClass,
    minPasswordCharacters,
    maxPasswordCharacters,
    suffixOptions,
    stateOptions
}