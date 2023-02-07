import { track, LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import labels from 'c/labelService';
import getCenter from '@salesforce/apex/SchedulerController.getCenter';
import getAppointments from '@salesforce/apex/SchedulerController.getAppointments';
import scheduleVisit from '@salesforce/apex/SchedulerController.scheduleVisit';

export default class Scheduler extends NavigationMixin(LightningElement) {

    labels = labels;
    currentPage = 'Scheduler';
geo;
    loading = true;
    appointmentDate;
    center = {};
    showTabs = false;
    @track appointments = [];
    @track appointmentGroups = {};

    appointmentSelected = false;

    get showScheduler() {
        return (this.currentPage === 'Scheduler');
    }

    get showCenter() {
        return (this.currentPage === 'Center');
    }

    connectedCallback() {
        const now = new Date();
        const day = ('0' + now.getDate()).slice(-2);
        const month = ('0' + (now.getMonth() + 1)).slice(-2);
        const year = now.getFullYear();

        this.appointmentDate = year + '-' + month + '-' + day;

        this.loadCenter();
    }

    onAppointmentDateChange(event) {
        this.appointmentDate = event.detail.value;

        this.loadAppointments();
    }

    onToggleTabsClick() {
        this.showTabs = !this.showTabs;
    }

    onViewCenterClick() {
        this.currentPage = 'Center';
    }

    onBackButtonClick() {
        this.currentPage = 'Scheduler';
    }

    onChooseAnotherCenterClick(event) {
        event.preventDefault();
    }

    onAppointmentButtonClick(event) {
        let index = event.target.dataset.index;
        let appointment = this.appointments[index];

        const previouslySelected = appointment.selected;

        this.appointments.forEach((appointment) => {
            appointment.selected = false;
            appointment.classes = 'appointment-button';
        });

        appointment.selected = !previouslySelected;
        appointment.classes = 'appointment-button ' + (appointment.selected ? 'selected' : '');

        this.appointmentSelected = appointment.selected;
    }

    onCancelButtonClick() {
        this[NavigationMixin.Navigate]({
            type: 'comm__loginPage',
            attributes: {
                actionName: 'logout'
            }
        });
/*
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(position => {
                // Get the Latitude and Longitude from Geolocation API
                var latitude = position.coords.latitude;
                var longitude = position.coords.longitude;

                console.log('latitude', latitude);
                console.log('longitude', longitude);
                this.geo = latitude;
            });
        } else {
            console.log('no geolocation!!');
            this.geo = 'no geolocation!!';
        }
*/
    }

    onScheduleButtonClick() {
        this.loading = true;

        const selectedAppointment = this.appointments.find((appointment) => appointment.selected);

        const request = {
            appointmentId: selectedAppointment.id
        };

        console.log('request', JSON.stringify(request));

        scheduleVisit(request).then(response => {
            console.log('response', response);

            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: 'Appointments__c'
                }
            });
        }).catch((error) => {
            console.log(error);
        }).finally(() => {
            this.loading = false;
        });
    }

    loadCenter() {
        this.loading = true;

        const request = {
        };

        console.log('request', JSON.stringify(request));

        getCenter(request).then(response => {
            console.log('response', response);
            this.center = response;

            this.loadAppointments();
        }).catch((error) => {
            console.log(error);
            this.loading = false;
        });
    }

    loadAppointments() {
        this.loading = true;

        const request = {
            centerId: this.center.id,
            appointmentDate: this.appointmentDate
        };

        console.log('request', JSON.stringify(request));

        getAppointments(request).then(response => {
            console.log('response', response);
            //this.appointments = response;
            this.appointments = [];

            this.appointmentGroups = response;

            this.appointments.push.apply(this.appointments, this.appointmentGroups.morningAppointments);
            this.appointments.push.apply(this.appointments, this.appointmentGroups.afternoonAppointments);
            this.appointments.push.apply(this.appointments, this.appointmentGroups.eveningAppointments);

            this.appointments.forEach((appointment) => {
                appointment.classes = 'appointment-button';
                appointment.available = (appointment.availability > 0);
            });
        }).catch((error) => {
            console.log(error);
        }).finally(() => {
            this.loading = false;
        });
    }

}