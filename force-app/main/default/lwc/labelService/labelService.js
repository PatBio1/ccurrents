import cancel from '@salesforce/label/c.Cancel';
import chooseAnotherClinic from '@salesforce/label/c.Choose_Another_Clinic';
import chooseDate from '@salesforce/label/c.Choose_Date';
import perPt from '@salesforce/label/c.Per_Pt';
import schedule from '@salesforce/label/c.Schedule';
import scheduleYour1stAppointment from '@salesforce/label/c.Schedule_Your_1st_Appointment';
import selectTimeSlot from '@salesforce/label/c.Select_Time_Slot';

const labels = {
    formatLabel: function (label, args) {
        return label.replace(/{(\d+)}/gm, (match, index) => {
            return args[index] === undefined ? '' : `${args[index]}`;
        });
    },

    // Alphabetical Order
    cancel,
    chooseAnotherClinic,
    chooseDate,
    perPt,
    schedule,
    scheduleYour1stAppointment,
    selectTimeSlot
};

export default labels;