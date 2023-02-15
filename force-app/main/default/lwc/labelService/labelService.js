import about from '@salesforce/label/c.About';
import aboutDonationExperience from '@salesforce/label/c.About_Donation_Experience';
import address from '@salesforce/label/c.Address';
import alreadyHaveAnAccount from '@salesforce/label/c.Already_Have_An_Account';
import back from '@salesforce/label/c.Back';
import backToCenters from '@salesforce/label/c.Back_To_Centers';
import backToHomepage from '@salesforce/label/c.Back_To_Homepage';
import basicProfile from '@salesforce/label/c.Basic_Profile';
import bus from '@salesforce/label/c.Bus';
import cancel from '@salesforce/label/c.Cancel';
import car from '@salesforce/label/c.Car';
import centers from '@salesforce/label/c.Centers';
import centerVideo from '@salesforce/label/c.Center_Video';
import change from '@salesforce/label/c.Change';
import changeLocation from '@salesforce/label/c.Change_Location';
import chooseACenter from '@salesforce/label/c.Choose_A_Center';
import chooseAnotherCenter from '@salesforce/label/c.Choose_Another_Center';
import chooseDate from '@salesforce/label/c.Choose_Date';
import city from '@salesforce/label/c.City';
import closed from '@salesforce/label/c.Closed';
import confirmPassword from '@salesforce/label/c.Confirm_Password';
import congratulations from '@salesforce/label/c.Congratulations';
import email from '@salesforce/label/c.Email';
import english from '@salesforce/label/c.English';
import enterPassword from '@salesforce/label/c.Enter_Password';
import firstName from '@salesforce/label/c.First_Name';
import fridayAbbreviation from '@salesforce/label/c.Friday_Abbreviation';
import howWillYouGetToCenter from '@salesforce/label/c.How_Will_You_Get_To_Center';
import invalidZipCode from '@salesforce/label/c.Invalid_Zip_Code';
import joinUs from '@salesforce/label/c.Join_Us';
import lastName from '@salesforce/label/c.Last_Name';
import middleName from '@salesforce/label/c.Middle_Name';
import mobilePhone from '@salesforce/label/c.Mobile_Phone';
import mondayAbbreviation from '@salesforce/label/c.Monday_Abbreviation';
import myAppointments from '@salesforce/label/c.My_Appointments';
import myLocation from '@salesforce/label/c.My_Location';
import myRewards from '@salesforce/label/c.My_Rewards';
import next from '@salesforce/label/c.Next';
import nickname from '@salesforce/label/c.Nickname';
import notifications from '@salesforce/label/c.Notifications';
import past from '@salesforce/label/c.Past';
import perPt from '@salesforce/label/c.Per_Pt';
import personalInformation from '@salesforce/label/c.Personal_Information';
import plasmaDonationSavesLives from '@salesforce/label/c.Plasma_Donation_Saves_Lives';
import popularTimes from '@salesforce/label/c.Popular_Times';
import previous from '@salesforce/label/c.Previous';
import recommendedToYou from '@salesforce/label/c.Recommended_To_You';
import resultsFor from '@salesforce/label/c.Results_For';
import saturdayAbbreviation from '@salesforce/label/c.Saturday_Abbreviation';
import schedule from '@salesforce/label/c.Schedule';
import scheduled from '@salesforce/label/c.Scheduled';
import scheduleYour1stAppointment from '@salesforce/label/c.Schedule_Your_1st_Appointment';
import selectTimeSlot from '@salesforce/label/c.Select_Time_Slot';
import setYourPassword from '@salesforce/label/c.Set_Your_Password';
import socialPicture from '@salesforce/label/c.Social_Picture';
import spanish from '@salesforce/label/c.Spanish';
import state from '@salesforce/label/c.State';
import streetAddress1 from '@salesforce/label/c.Street_Address_1';
import streetAddress2 from '@salesforce/label/c.Street_Address_2';
import suffix from '@salesforce/label/c.Suffix';
import sundayAbbreviation from '@salesforce/label/c.Sunday_Abbreviation';
import taxi from '@salesforce/label/c.Taxi';
import tellUsAboutYou from '@salesforce/label/c.Tell_Us_About_You';
import thursdayAbbreviation from '@salesforce/label/c.Thursday_Abbreviation';
import tuesdayAbbreviation from '@salesforce/label/c.Tuesday_Abbreviation';
import updatesAndAppointments from '@salesforce/label/c.Updates_And_Appointments';
import walk from '@salesforce/label/c.Walk';
import wednesdayAbbreviation from '@salesforce/label/c.Wednesday_Abbreviation';
import welcomeToProesis from '@salesforce/label/c.Welcome_To_Proesis';
import workingHours from '@salesforce/label/c.Working_Hours';
import zipCode from '@salesforce/label/c.Zip_Code';

const labels = {
    formatLabel: function (label, args) {
        return label.replace(/{(\d+)}/gm, (match, index) => {
            return args[index] === undefined ? '' : `${args[index]}`;
        });
    },

    // Alphabetical Order
    about,
    aboutDonationExperience,
    address,
    alreadyHaveAnAccount,
    back,
    backToCenters,
    backToHomepage,
    basicProfile,
    bus,
    cancel,
    car,
    centers,
    centerVideo,
    change,
    changeLocation,
    chooseACenter,
    chooseAnotherCenter,
    chooseDate,
    city,
    closed,
    confirmPassword,
    congratulations,
    email,
    english,
    enterPassword,
    firstName,
    fridayAbbreviation,
    howWillYouGetToCenter,
    invalidZipCode,
    joinUs,
    lastName,
    middleName,
    mobilePhone,
    mondayAbbreviation,
    myAppointments,
    myLocation,
    myRewards,
    next,
    nickname,
    notifications,
    past,
    perPt,
    personalInformation,
    plasmaDonationSavesLives,
    popularTimes,
    previous,
    recommendedToYou,
    resultsFor,
    saturdayAbbreviation,
    schedule,
    scheduled,
    scheduleYour1stAppointment,
    selectTimeSlot,
    setYourPassword,
    socialPicture,
    spanish,
    state,
    streetAddress1,
    streetAddress2,
    suffix,
    sundayAbbreviation,
    taxi,
    tellUsAboutYou,
    thursdayAbbreviation,
    tuesdayAbbreviation,
    updatesAndAppointments,
    walk,
    wednesdayAbbreviation,
    welcomeToProesis,
    workingHours,
    zipCode
};

export default labels;