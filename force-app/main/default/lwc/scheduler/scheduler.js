import { track, LightningElement } from 'lwc';
import labels from 'c/labelService';
import getCenter from '@salesforce/apex/SchedulerController.getCenter';
import getAppointments from '@salesforce/apex/SchedulerController.getAppointments';
import scheduleVisit from '@salesforce/apex/SchedulerController.scheduleVisit';

export default class Scheduler extends LightningElement {

    labels = labels;

    loading = true;
    centerId = '001Dn00000Br6lLIAR';
    donorId = '003Dn000006euP5IAI';
    appointmentDate;
    center = {};
    @track appointments = [];

    appointmentSelected = false;

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

    onViewCenterClick() {
        this.dispatchEvent(new CustomEvent('redirect', {detail: {url: '/apex/Center'}}));
    }

    onChooseAnotherClinicClick(event) {
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

    onScheduleButtonClick() {
        this.loading = true;

        const selectedAppointment = this.appointments.find((appointment) => appointment.selected);

        const request = {
            donorId: this.donorId,
            appointmentId: selectedAppointment.id
        };

        console.log('request', JSON.stringify(request));

        scheduleVisit(request).then(response => {
            console.log('response', response);
        }).catch((error) => {
            console.log(error);
        }).finally(() => {
            this.loading = false;
        });
    }

    loadCenter() {
        this.loading = true;

        const request = {
            centerId: this.centerId
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
            centerId: this.centerId,
            appointmentDate: this.appointmentDate
        };

        console.log('request', JSON.stringify(request));

        getAppointments(request).then(response => {
            console.log('response', response);
            this.appointments = response;

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