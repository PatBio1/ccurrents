import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import TIME_ZONE from '@salesforce/i18n/timeZone';
import STATUS_FIELD from '@salesforce/schema/Visit__c.Status__c';
import OUTCOME_FIELD from '@salesforce/schema/Visit__c.Outcome__c';

import getCenters from '@salesforce/apex/CenterScheduleController.getCenters';
import getAppointments from '@salesforce/apex/CenterScheduleController.getAppointments';
import getAppointmentSlot from '@salesforce/apex/CenterScheduleController.getAppointmentSlot';
import ChangeVisitAppointment from '@salesforce/apex/CenterScheduleController.changeVisitAppointment';
import cancelVisit from '@salesforce/apex/CenterScheduleController.cancelVisit';

import { visitStatusToDisplayClass, visitOutcomeToDisplayClass } from "c/constants";
import CreateScheduleModal from "c/createScheduleModal";
import AddVisitModal from "c/addVisitModal";
import CreateDonorModal from 'c/createDonorModal';

import hasCenterManagerPerms from '@salesforce/customPermission/Center_Manager_Actions';

export default class CenterScheduler extends NavigationMixin(LightningElement) {
    statusOptions;
    outcomeOptions;
    filterOnNull = true;

    //hardcoded to null recordTypeId, since we don't use RTs on Visit__c
    @wire(getPicklistValues, { fieldApiName: STATUS_FIELD, recordTypeId: '012000000000000AAA' })
    getStatusValues({ error, data }) {
        if (data) {
            // API names for Status Picklist values that don't need to be displayed as a filter option
            const omittedStatuses = ["New", "Complete"];
            
            if (data.values.length > visitStatusToDisplayClass.size) {
                console.error("There aren't enough configured status colors for the queried statuses");
            }

            this.statusOptions = data.values.filter((status => !omittedStatuses.includes(status.value))).map((status) => {
                return {...status, displayClass: `legend-icon ${visitStatusToDisplayClass.get(status.value)}`}
            });

            console.log("Found Statuses", this.statusOptions);
        } else if(error) {    
            console.log("Status Values Fetch", error);
        }
    }

    @wire(getPicklistValues, { fieldApiName: OUTCOME_FIELD, recordTypeId: '012000000000000AAA' })
    getOutcomeValues({ error, data }) {
        if (data) {
            if (data.values.length > visitOutcomeToDisplayClass.size) {
                console.error("There aren't enough configured outcome colors for the queried outcomes");
            }

            this.outcomeOptions = data.values.map((outcome) => {
                return {...outcome, displayClass: `legend-icon ${visitOutcomeToDisplayClass.get(outcome.value)}`}
            });

            console.log("Found Outcomes", this.outcomeOptions);
        } else if(error) {    
            console.log("Outcome Values Fetch", error);
        }
    }
    
    @track selectedCenterId;
    @track selectedDate
    @track appointments;
    centers = [];
    tz=TIME_ZONE;

    showFilters=false;
    initDefaultFilters=false;
    show = false;
    dateDisabled = true;
    loading = true;
    popYFlipPoint;

    get isCenterManager() {
        return (hasCenterManagerPerms);
    }

    get cantRefresh() {
        return (this.dateDisabled || !this.selectedDate)
    }

    get createDonorDisabled() {
        return (!this.selectedCenterId);
    }

    get hasAppointmentsToDisplay() {
        return (this.appointments && this.appointments.length);
    }

    @track filters = {
        start: '',
        end: '',
        status: [],
        outcome: [],

        hasStatusFilters: function() {
            return (this.status !== null && this.status.length > 0);
        },
        hasOutcomeFilters: function() {
            return (this.outcome !== null && this.outcome.length > 0);
        },

        hasActiveFilters: function() {
            return (this.hasStatusFilters() || this.hasOutcomeFilters());
        },

        passesFilters: function(visit, filterOnNull) {
            if (!this.hasStatusFilters() && !this.hasOutcomeFilters()) {
                return true;
            }

            return (this.status.includes(visit.status) || this.outcome.includes(visit.outcome))
        }
    }

    showPopover() {
        this.show = !this.show;
    }

    connectedCallback() {
        this.loadCenters();
    }

    renderedCallback() {
        this.calculatePopoverFlipPoint();

        if (this.hasAppointmentsToDisplay && !this.initDefaultFilters) {
            // Apply Default Filters
            this.handleSelectNewFilter(this.template.querySelector(".legend-entry[data-status-api-name='Scheduled']"), "Scheduled", "status");
            this.handleSelectNewFilter(this.template.querySelector(".legend-entry[data-status-api-name='Checked-In']"), "Checked-In", "status");
            this.handleSelectNewFilter(this.template.querySelector(".legend-entry[data-outcome-api-name='Donation']"), "Donation", "outcome");
            this.applyFilters();

            this.initDefaultFilters = true;
        }

        for(let filterButton of [
            ...this.template.querySelectorAll(".legend-entry[data-status-api-name]"),
            ...this.template.querySelectorAll(".legend-entry[data-outcome-api-name]") 
        ]) {
            if (
                (filterButton.dataset.statusApiName && this.filters.status.includes(filterButton.dataset.statusApiName)) ||
                (filterButton.dataset.outcomeApiName && this.filters.outcome.includes(filterButton.dataset.outcomeApiName)) 
            ) {
                filterButton.classList.add("slds-button_brand");
            }
        }
    }

    refresh() {
        this.fetchAppointments();
    }

    calculatePopoverFlipPoint() {
        if (this.popYFlipPoint) {
            return;
        }

        let appointmentContainer = this.template.querySelector("div.appointments");
        if (!appointmentContainer) {
            return;
        }

        let appointmentBoundingBox = appointmentContainer.getBoundingClientRect();
        this.popYFlipPoint = appointmentBoundingBox.y + (appointmentBoundingBox.height / 2);
    }

    openNewScheduleModal() {
        CreateScheduleModal.open({
            // pass data for the @api properties declared in the Modal component
            centerId: this.selectedCenterId,
            // Bind the events dispatched from the Modal component
            onselect: (e) => {
                e.stopPropagation();
                // Call function to handle the selection event
                this.handleSelectEvent(e.detail);
            }
        }).then((result) => {
            // Promise handler for the Modal opening
            // Result has values passed via the close event from the Modal component
            console.log(result);
            this.selectedDate = result;
            this.refresh();
        }).catch(err =>{
            console.log(err.message);
        })
        .finally(()=>{
            this.loading = false;
        });
    }
    
    drop(event) {
        
        event.preventDefault();
        var donorId = event.dataTransfer.getData("donorId");
        var appointmentId = event.dataTransfer.getData("appointmentId");
        var appointmentTime = event.dataTransfer.getData("appointmentTime");
        var visitId = event.dataTransfer.getData("visitId");
        var initials = event.dataTransfer.getData("initials");
        var donorName = event.dataTransfer.getData("donorName");
        var newAppointmentId = event.target.dataset.appointment;
        var newOppointmentTime = event.target.dataset.appointmenttime;
        event.target.classList.remove('drop-ok');
        
        // bad drop on wrong target
        if(!newAppointmentId){
            this.showToast('Appointment was not rescheduled, please drop it again','Woops!','warning');
            return;
        }

        // dropped in same row no change
        if(appointmentId == newAppointmentId){
            return;
        }

        let appointmentData = this.appointments.find((appointment) => appointment.Id === newAppointmentId);
        if (!appointmentData || appointmentData.cantAddVisit) {
            alert("This appointment slot doesn't have any remaining capacity");
            return;
        }

        //last chance to back out
        if(!confirm(`Really change appointment time for ${donorName} from ${appointmentTime} to ${newOppointmentTime}?`)){
            return;
        }
 
        this.loading = true;

        ChangeVisitAppointment({
            visitId, 
            appointmentId : newAppointmentId
        }).then(async ()=>{
            
            this.showToast(`for ${donorName} from ${appointmentTime} to ${newOppointmentTime}`, 'Changed Appointment', 'success');
            for(let i=0;i< this.appointments.length;i++){
                let appRow = this.appointments[i];
                //old row
                if(appRow.Id == appointmentId){
                    appRow.visits = [];
                    this.refreshAppointmentSlot(appointmentId, appRow);
                    
                }
                //new row
                if(appRow.Id == newAppointmentId){
                    appRow.visits = [];
                    this.refreshAppointmentSlot(newAppointmentId, appRow);
                }
                
            }
        }).catch(err => {
            this.showToast(err.message,'There was a problem','error');
            console.debug(err);
        }).finally(() =>{
            this.loading = false;
            
            // this.refresh();
        });

    }

    allowDrop(event) {
        event.preventDefault();
    }

    dragenter(event) {
        let newAppointmentId = event.target.dataset.appointment;
        let appointmentData = this.appointments.find((appointment) => appointment.Id === newAppointmentId);

        if (appointmentData && !appointmentData.cantAddVisit) {
            event.target.classList.add('drop-ok');
        }
    }

    dragleave(event) {
        event.target.classList.remove('drop-ok');
    }    

    get filterLabel() {
        if (this.showFilters) {
            return 'Hide Filters'
        } else {
            return 'Show Filters'
        }
    }

    get appointmentTypes() {
        return [
            {label:'induction', value:'induction'},
            {label:'plasma donation', value:'plasma donation'},
            {label:'some other type', value:'some other type'}
        ]
    }

    toggleFilters() {
        console.log('toggle')
        this.showFilters = !this.showFilters;
    }

    filterChange(event) {
        console.log(event);
    }

    applyFilters() {
        // only visits are filtered in js, not appointments
        // for each visit in each app row
        for(let appointment of this.appointments) {
            if (appointment.visits && appointment.visits.length > 0) {
                for(let visit of appointment.visits) {

                    let newFilterStatus = (
                        this.filters.hasActiveFilters() &&
                        !this.filters.passesFilters(visit, this.filterOnNull)
                    );

                    visit.filtered = newFilterStatus;
                }
            }
        }
    }

    clearFilters() {
        console.log(this.filters);
        this.filters.start = '';
        this.filters.end = '';
        this.filters.status = [];
        this.filters.outcome = [];

        for(let i=0;i < this.appointments.length;i++){
            let app = this.appointments[i];
            app.filtered = false;
            //for each visit in this app row
            if(app.visits.length){
                for(let j=0; j<app.visits.length;j++){
                    let visit = app.visits[j];
                    visit.filtered = false;
                }
            }
        }
        
    }
    changeFilterStart(event){
        this.filters.start =  event.target.value;
    }
    changeFilterEnd(event){
        this.filters.end =  event.target.value;
    }

    loadCenters() {
        
        getCenters().then(centers => {

            this.centers = centers;
        }).catch((error) => {
            console.log(error);
        }).finally(() => {
            this.loading = false;
        });
  
    }

    async fetchAppointments(){
        this.appointments = [];    
        this.loading = true;

        let queriedAppointments = await getAppointments({
            centerId: this.selectedCenterId,
            appointmentDay: this.selectedDate,
            timeStart: this.filters.start,
            timeStop: this.filters.end
        });

        let generateUrlPromises = [];
        for(let appointment of queriedAppointments) {
            // Used to show/hide Add Visit on per row basis
            appointment.cantAddVisit = !((appointment.availability > 0 || appointment.loyaltyAvailability > 0) && !appointment.isInThePast);
            console.log(`${appointment.timeString}: ${appointment.booked}`);

            generateUrlPromises.push(
                this[NavigationMixin.GenerateUrl]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: appointment.Id,
                        actionName: 'view',
                    }
                }).then((url) => {
                    appointment.link = url;
                })
            );
        }

        try {
            await Promise.all(generateUrlPromises);
        } catch(generateUrlError) {
            console.log("generateUrlError", generateUrlPromises);
        } finally {
            this.appointments = queriedAppointments;
            if (this.filters.hasActiveFilters()) {
                this.applyFilters();
            }

            this.loading = false;
        }
    }

    changeCenter(event){
        this.selectedCenterId = event.detail.value;
        this.dateDisabled = false;
    }

    changeDate(event){
        if (!event.detail.value) {
            return;
        }

        this.selectedDate = event.detail.value;
        this.fetchAppointments();
    }   
    
    changeStatusFilter(event){
        this.filters.status = event.detail.value;
    }

    showToast(message, title, variant){
        title = (title ? title : '');
        variant = (variant ? variant : 'info');
        message = (message ? message : 'no message');
        this.dispatchEvent(
            new ShowToastEvent({
                message,
                variant,
                title
            })
        );
    }

    // this works for the timepicker time format 00:00:00:00:00
    // and also for the timestring in our Appointment labels 9:00 AM
    timeToDate(timestring){
        // take provided time

        let stringparts = timestring.split(' ')
        let timeparts = stringparts[0].split(':');
        let hours = parseInt(timeparts[0]);
        if(stringparts[1] === 'PM'){
            hours = hours + 12;
        }
        let minutes = timeparts[1];

        // apply to current schedule date
       let dateparts  = this.selectedDate.split('-');

       let year = dateparts[0];
       let month = parseInt(dateparts[1]) -1; //month in js offset!
       let day = dateparts[2]

        const newDate = new Date(parseInt(year), parseInt(month), parseInt(day), parseInt(hours), parseInt(minutes) );

        return newDate;
    }

    handleCancelVisit(event) {
        if(confirm(`Really cancel visit for ${event.detail.donorName}?`)){
            cancelVisit({
                visitId : event.detail.visitId
            }).then(() => {
                for(let i=0;i< this.appointments.length;i++){
                    let appRow = this.appointments[i];
                    if(appRow.Id == event.detail.appointmentId){
                        appRow.visits = [];
                        this.refreshAppointmentSlot(event.detail.appointmentId, appRow);
                    }
                }
            });
        }
    }

    async refreshAppointmentSlot(appointmentId, appRow){
        await getAppointmentSlot({appointmentId }).then(appointment => {
            appRow.visits = appointment.visits;
            appRow.booked = appointment.booked;
            appRow.loyaltyBooked = appointment.loyaltyBooked;
            appRow.totalBooked = appointment.totalBooked;
            appRow.availability = appointment.availability;
            appRow.loyaltyAvailability = appointment.loyaltyAvailability;
            appRow.cantAddVisit = !((appointment.availability > 0 || appointment.loyaltyAvailability) && !appointment.isInThePast);

            if (this.filters.hasActiveFilters()) {
                this.applyFilters();
            }
        }).catch(err => {
            console.log(err.message);
        })
    }

    handleSelectNewFilter(newFilterButton, newFilterApiName, filterName) {
        let existingFilterIndex = this.filters[filterName].findIndex((selectedFilter) => selectedFilter === newFilterApiName);

        if (existingFilterIndex != -1) {
            this.filters[filterName].splice(existingFilterIndex, 1);
        } else {
            this.filters[filterName].push(newFilterApiName);
        }

        newFilterButton.classList.toggle("slds-button_brand");
    }

    handleSelectStatus(event) {
        let targetStatus = event.currentTarget.dataset.statusApiName;

        this.handleSelectNewFilter(event.currentTarget, targetStatus, "status");
        this.applyFilters();
    }

    handleSelectOutcome(event) {
        let targetOutcome = event.currentTarget.dataset.outcomeApiName;
        if (targetOutcome === "None") {
            targetOutcome = undefined;
        }

        this.handleSelectNewFilter(event.currentTarget, targetOutcome, "outcome");
        this.applyFilters();
    }

    handleInitAddVisit(event) {
        let targetAppointmentId = event.currentTarget.dataset.appointment;
        let appointmentRecord = this.appointments.find(appointment => appointment.Id === targetAppointmentId);

        AddVisitModal.open({
            appointmentSlotId: targetAppointmentId,
            appointmentSlotDate: this.selectedDate,
            appointmentSlotTime: event.currentTarget.dataset.appointmenttime,
            centerId: this.selectedCenterId,
            hasLoyaltyAvailability: appointmentRecord.loyaltyAvailability > 0,
            hasAvailability: appointmentRecord.availability > 0,

            onvisitcreated: (event) => {
                event.stopPropagation();
                this.handleVisitCreated(event, targetAppointmentId);
            }
        });
    }

    handleVisitCreated(event, appointmentId) {
        this.refreshAppointmentSlot(
            appointmentId,
            this.appointments.find(appointment => appointment.Id === appointmentId)
        );
    }

    handleDifferentDayReschedule(event) {
        let oldAppointmentId = event.detail.oldAppointmentId;
        let newAppointmentId = event.detail.newAppointmentId;

        let oldAppointment = this.appointments.find(appointment => appointment.Id === oldAppointmentId);
        let newAppointment = this.appointments.find(appointment => appointment.Id === newAppointmentId);

        if (oldAppointment) {
            this.refreshAppointmentSlot(oldAppointmentId, oldAppointment);
        }

        if (newAppointment) {
            this.refreshAppointmentSlot(newAppointmentId, newAppointment);
        }
    }

    handleInitCreateDonor(event) {
        CreateDonorModal.open({
            selectedCenter: this.selectedCenterId,

            ondonorcreated: (event) => {
                if (!this.selectedDate) {
                    this.selectedDate = new Date(Date.now()).toISOString();
                }

                event.stopPropagation();
                
                if (event.detail.wasVisitScheduled) {
                    this.fetchAppointments();
                }
            }
        });
    }
}