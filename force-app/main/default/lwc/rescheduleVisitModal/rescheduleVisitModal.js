import { LightningElement, api } from 'lwc';
import LightningModal from 'lightning/modal';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getSoonestNextRescheduleVisitDate from '@salesforce/apex/CoreSchedulerHandler.getSoonestNextRescheduleVisitDate';
import getAvailableRescheduleAppointmentRange from '@salesforce/apex/CenterScheduleController.getAvailableRescheduleAppointmentRange';
import changeVisitAppointment from '@salesforce/apex/CenterScheduleController.changeVisitAppointment';

export default class RescheduleVisitModal extends LightningModal {
    @api existingVisitAppointmentId;
    @api existingVisitId;
    @api donorId;
    @api originDate;
    @api centerId;

    groupedAppointments;
    soonestNextVisit;

    selectedAppointmentGroupIndex;
    selectedStartDate;
    adjustedStartDate;

    selectedEndDate;
    adjustedEndDate;
    refreshAppointmentSlotsTimeout;

    isLoading = false;
    isInitialized = false;
    isDefaultAppointmentGroupInitialized = false;

    get adjustedSoonestNextVisit() {
        if (!this.soonestNextVisit) {
            return Date.now();
        }

        if (this.soonestNextVisit < Date.now()) {
            return Date.now();
        }

        return this.soonestNextVisit;
    }

    get minimumStartDate() {
        if (!this.soonestNextVisit && !this.selectedEndDate) {
            return null;
        }

        let targetMinDate;
        if (!this.selectedEndDate) {
            targetMinDate = this.soonestNextVisit;
        } else if (!this.soonestNextVisit) {
            targetMinDate = this.selectedEndDate;
        } else {
            targetMinDate = this.selectedEndDate > this.soonestNextVisit ? this.selectedEndDate : this.soonestNextVisit;
        }

        return new Date(targetMinDate);
    }

    get selectedAppointmentGroup() {
        if (!this.groupedAppointments) {
            return null;
        }

        return this.groupedAppointments[this.selectedAppointmentGroupIndex];
    }

    async renderedCallback() {
        if (!this.isInitialized) {
            await this.initSoonestNextVisitDate();
            this.initDefaultDateRange();
        }

        if (!this.isDefaultAppointmentGroupInitialized) {
            this.toggleAppointmentGroup(
                this.selectedAppointmentGroupIndex !== null && this.selectedAppointmentGroupIndex !== undefined ? this.selectedAppointmentGroupIndex : 0
            );

            this.isDefaultAppointmentGroupInitialized = true;
        }
    }

    async initSoonestNextVisitDate() {
        if (!this.donorId) {
            return;
        }

        this.isLoading = true;

        let serverSoonestNextVisitDateTime = await getSoonestNextRescheduleVisitDate({ donorId: this.donorId, visitToReschedule: this.existingVisitId });
        this.soonestNextVisit = new Date(serverSoonestNextVisitDateTime);

        this.isLoading = false;
        this.isInitialized = true;
    }

    initDefaultDateRange() {
        this.adjustedStartDate = new Date(this.originDate);
        this.adjustedStartDate.setHours(0);
        this.adjustedStartDate.setMinutes(0);
        this.adjustedStartDate.setSeconds(0);
        this.adjustedStartDate.setMilliseconds(0);

        this.selectedStartDate = this.adjustedStartDate.toISOString();
        
        this.adjustedEndDate = new Date(this.adjustedStartDate);
        this.adjustedEndDate.setDate(this.adjustedEndDate.getDate() + 7);
        this.adjustedEndDate.setHours(23);
        this.adjustedEndDate.setMinutes(59);
        this.adjustedEndDate.setSeconds(59);
        this.adjustedEndDate.setMilliseconds(999);

        this.selectedEndDate = this.adjustedEndDate.toISOString();

        this.fetchRescheduleAppointmentsByRange();
    }

    async fetchRescheduleAppointmentsByRange() {
        this.isLoading = true;
        let availableAppointments = await getAvailableRescheduleAppointmentRange({
            centerId: this.centerId,
            currentDateTime: new Date(Date.now()),
            soonestNextVisit: this.soonestNextVisit,
            searchStartDateTime: this.adjustedStartDate,
            searchEndDateTime: this.adjustedEndDate,
            isLoyaltyDonor: false
        });
        
        if (!availableAppointments) {
            console.error('No Appointments Found');
            return;
        }

        let appointmentsByDay = new Map();
        for(let availableAppointment of availableAppointments) {
            availableAppointment.appointmentDateTime = new Date(availableAppointment.appointmentDateTime);
            availableAppointment.timeDisplay = availableAppointment.appointmentDateTime.toLocaleTimeString('en-US', {
                hour: "2-digit",
                minute: "2-digit",
                hour12: true
            });

            let appointmentKey = `${availableAppointment.appointmentDateTime.getFullYear()}-${availableAppointment.appointmentDateTime.getMonth()}-${availableAppointment.appointmentDateTime.getDate()}`;
            let appointmentsForDate = appointmentsByDay.get(appointmentKey);
            if (!appointmentsForDate) {
                let weekday = availableAppointment.appointmentDateTime.toLocaleDateString('en-US', { weekday: 'short' });
                let mainDisplay = availableAppointment.appointmentDateTime.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });

                appointmentsForDate = {
                    weekDayDisplay: weekday,
                    dayMonthYearDisplay: mainDisplay,
                    appointments: []
                }
            }

            appointmentsForDate.appointments.push(availableAppointment);
            appointmentsByDay.set(appointmentKey, appointmentsForDate)
        }
    
        if (this.selectedAppointmentGroupIndex !== null && this.selectedAppointmentGroupIndex !== undefined) {
            this.toggleAppointmentGroup(this.selectedAppointmentGroupIndex);
        }

        this.selectedAppointmentGroupIndex = 0;
        this.isDefaultAppointmentGroupInitialized = false;
        this.isLoading = false;
        this.groupedAppointments = [...appointmentsByDay.values()];
    }

    handleUpdateSearchDate(event) {
        let targetDateField = event.currentTarget.dataset.searchDate;

        let dateValue = new Date(...event.detail.value.split('-'));
        dateValue.setMonth(dateValue.getMonth() - 1); 

        if (targetDateField === "Start") {
            dateValue.setHours(0);
            dateValue.setMinutes(0);
            dateValue.setSeconds(0);
            dateValue.setMilliseconds(0);

            if (dateValue < new Date(this.minimumStartDate.getFullYear(), this.minimumStartDate.getMonth(), this.minimumStartDate.getDate(), 0, 0, 0)) {
                event.currentTarget.setCustomValidity(`Start date must be after or equal to ${this.minimumStartDate.toLocaleString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}`);
                return;
            } else {
                event.currentTarget.setCustomValidity('');
            }

            this.selectedStartDate = dateValue.toISOString();
            this.adjustedStartDate = dateValue;
        } else {
            dateValue.setHours(23);
            dateValue.setMinutes(59);
            dateValue.setSeconds(59);
            dateValue.setMilliseconds(999);

            if (this.adjustedStartDate && dateValue < this.adjustedStartDate) {
                event.currentTarget.setCustomValidity(`End date must be after or equal to ${this.adjustedStartDate.toLocaleString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}`);
                return;
            } else {
                event.currentTarget.setCustomValidity('');
            }

            this.selectedEndDate = event.detail.value;
            this.adjustedEndDate = dateValue;
        }

        if (this.selectedStartDate && this.selectedEndDate) {
            if (this.refreshAppointmentSlotsTimeout) {
                clearTimeout(this.refreshAppointmentSlotsTimeout);
            }

            this.refreshAppointmentSlotsTimeout = setTimeout(() => this.fetchRescheduleAppointmentsByRange(), 250)
        }
    }

    handleSelectAppointmentGroup(event) {
        // Exit function if groupIndex is already selected
        if (this.selectedAppointmentGroupIndex === event.currentTarget.dataset.groupIndex) {
            return;
        }

        if (this.selectedAppointmentGroupIndex !== null && this.selectedAppointmentGroupIndex !== undefined) {
            this.toggleAppointmentGroup(this.selectedAppointmentGroupIndex);
        }

        this.toggleAppointmentGroup(event.currentTarget.dataset.groupIndex);
        this.selectedAppointmentGroupIndex= event.currentTarget.dataset.groupIndex;
    }

    toggleAppointmentGroup(appointmentGroupIndex) {
        let targetAppointmentGroupButton = this.template.querySelector(`div[data-group-index='${appointmentGroupIndex}']`);
        if (targetAppointmentGroupButton) {
            targetAppointmentGroupButton.classList.toggle('selected-group-header');
            targetAppointmentGroupButton.classList.toggle('group-header');
        }
    }

    async handleSelectNewAppointment(event) {
        let selectedAppointmentId = event.currentTarget.dataset.appointmentId;
        this.isLoading = true;

        try {
            await changeVisitAppointment({
                visitId: this.existingVisitId,
                appointmentId: selectedAppointmentId
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Visit Rescheduled',
                message: 'The visit has been rescheduled!',
                variant: 'success'
            }));

            this.dispatchEvent(new CustomEvent('visitrescheduled', { 
                detail: { 
                    oldAppointmentId: this.existingVisitAppointmentId, 
                    newAppointmentId: selectedAppointmentId 
                }   
            }));
            
            this.close();
        } catch (error) {
            console.error(error);
        } finally {
            this.isLoading = false;
        }
    }
}