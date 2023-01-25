import aboutDonationExperience from '@salesforce/label/c.About_Donation_Experience';
import alreadyHaveAnAccount from '@salesforce/label/c.Already_Have_An_Account';
import back from '@salesforce/label/c.Back';
import backToHomepage from '@salesforce/label/c.Back_To_Homepage';
import basicProfile from '@salesforce/label/c.Basic_Profile';
import cancel from '@salesforce/label/c.Cancel';
import centers from '@salesforce/label/c.Centers';
import chooseACenter from '@salesforce/label/c.Choose_A_Center';
import chooseAnotherCenter from '@salesforce/label/c.Choose_Another_Center';
import chooseDate from '@salesforce/label/c.Choose_Date';
import english from '@salesforce/label/c.English';
import firstName from '@salesforce/label/c.First_Name';
import joinUs from '@salesforce/label/c.Join_Us';
import lastName from '@salesforce/label/c.Last_Name';
import middleName from '@salesforce/label/c.Middle_Name';
import myAppointments from '@salesforce/label/c.My_Appointments';
import myRewards from '@salesforce/label/c.My_Rewards';
import next from '@salesforce/label/c.Next';
import past from '@salesforce/label/c.Past';
import perPt from '@salesforce/label/c.Per_Pt';
import plasmaDonationSavesLives from '@salesforce/label/c.Plasma_Donation_Saves_Lives';
import recommendedToYou from '@salesforce/label/c.Recommended_To_You';
import schedule from '@salesforce/label/c.Schedule';
import scheduled from '@salesforce/label/c.Scheduled';
import scheduleYour1stAppointment from '@salesforce/label/c.Schedule_Your_1st_Appointment';
import selectTimeSlot from '@salesforce/label/c.Select_Time_Slot';
import spanish from '@salesforce/label/c.Spanish';
import tellUsAboutYou from '@salesforce/label/c.Tell_Us_About_You';
import welcomeToProesis from '@salesforce/label/c.Welcome_To_Proesis';

const labels = {
    formatLabel: function (label, args) {
        return label.replace(/{(\d+)}/gm, (match, index) => {
            return args[index] === undefined ? '' : `${args[index]}`;
        });
    },

    // Alphabetical Order
    aboutDonationExperience,
    alreadyHaveAnAccount,
    back,
    backToHomepage,
    basicProfile,
    cancel,
    centers,
    chooseACenter,
    chooseAnotherCenter,
    chooseDate,
    english,
    firstName,
    joinUs,
    lastName,
    middleName,
    myAppointments,
    myRewards,
    next,
    past,
    perPt,
    plasmaDonationSavesLives,
    recommendedToYou,
    schedule,
    scheduled,
    scheduleYour1stAppointment,
    selectTimeSlot,
    spanish,
    tellUsAboutYou,
    welcomeToProesis
};

export default labels;