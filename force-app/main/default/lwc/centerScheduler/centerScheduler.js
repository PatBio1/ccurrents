import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import TIME_ZONE from '@salesforce/i18n/timeZone';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import STATUS_FIELD from '@salesforce/schema/Visit__c.Status__c';

import VISIT_OBJECT from '@salesforce/schema/Visit__c';


import getCenters from '@salesforce/apex/CenterScheduleController.getCenters';
import getAppointments from '@salesforce/apex/CenterScheduleController.getAppointments';
import getAppointmentSlot from '@salesforce/apex/CenterScheduleController.getAppointmentSlot';
import ChangeVisitAppointment from '@salesforce/apex/CenterScheduleController.changeVisitAppointment';
import CreateScheduleModal from "c/createScheduleModal";
import DonorDot from "c/donorDot";

export default class CenterScheduler extends NavigationMixin(LightningElement) {
    statusOptions;
    //hardcoded to null recordTypeId, since we don't use RTs on Visit__c
    @wire(getPicklistValues, { fieldApiName: STATUS_FIELD, recordTypeId: '012000000000000AAA' })
    wiredFields({ error, data }){
        if(data){
            this.statusOptions = data.values;
        }else if(error){    
            console.log(error);
        }
    }

    
    @track selectedCenterId;
    @track selectedDate
    @track appointments;
    centers = [];
    tz=TIME_ZONE;

    showFilters=false;
    show = false;
    dateDisabled = true;
    loading = true;

    @track filters = {
        start: '',
        end: '',
        status: ''
    }

    showPopover() {
        this.show = !this.show;
    }

    connectedCallback() {
        this.loadCenters();
    }

    refresh(){
        this.fetchAppointments();
    }

    openNewScheduleModal(){
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
        });
    }
    
    drop(event){
        
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
                    await getAppointmentSlot({appointmentId }).then(appointment => {
                        appRow.visits = appointment.visits;
                        appRow.booked = appointment.booked;
                        appRow.availability = appointment.availability;
                    })
                }
                //new row
                if(appRow.Id == newAppointmentId){
                    appRow.visits = [];
                    await getAppointmentSlot({appointmentId : newAppointmentId}).then(appointment => {
                        appRow.visits = appointment.visits;
                        appRow.booked = appointment.booked;
                        appRow.availability = appointment.availability;
                    })
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

    allowDrop(event){
        event.preventDefault();
    }

    dragenter(event){
        // console.log('drag enter')
        event.target.classList.add('drop-ok');
    }
    dragleave(event){
        // console.log('drag leave')
        event.target.classList.remove('drop-ok');
    }    


    get filterLabel(){
        if(this.showFilters){
            return 'Hide Filters'
        }else{
            return 'Show Filters'
        }
    }

    get appointmentTypes(){
        return [
            {label:'induction', value:'induction'},
            {label:'plasma donation', value:'plasma donation'},
            {label:'some other type', value:'some other type'}
        ]
    }

    toggleFilters(){
        console.log('toggle')
        this.showFilters = !this.showFilters;
    }

    filterChange(event){
        console.log(event);
    }

    applyFilters(){
        let startTime;
        if(this.filters.start){
            startTime = this.timeToDate(this.filters.start);
        }else{
            startTime = this.timeToDate('0:00 AM');
        }
        console.log('filter startTime ',startTime);
         
        let endTime 
        if(this.filters.end){
            endTime = this.timeToDate(this.filters.end);
        }else{
            endTime = this.timeToDate('11:59 PM');
        }
        
        console.log('filter endTime -> ', endTime);   
        //filter for appointments by time slot

        for(let i=0;i < this.appointments.length;i++){
            let app = this.appointments[i];
            let appDate = this.timeToDate(app.timeString);
            //figure this out
            if(startTime != 'Invalid Date' && endTime != 'Invalid Date'){
                if(appDate >= startTime  && appDate <= endTime){
                    // console.log('compare start :', startTime, ' end time: ', endTime,  ' to: slotdate: ',appDate);
                    app.filtered = false;
                }else{
                    app.filtered = true;
                }
            }
        }
        //for each visit in each app row
        for(let i=0;i < this.appointments.length;i++){
            let app = this.appointments[i];
            app = this.appointments[i];
            if(app.visits.length > 0 ){
                for(let j=0; j<app.visits.length;j++){
                    let visit = app.visits[j];
                    if(this.filters.status !== ''){
                        console.log('filter status',this.filters.status );
                        if(visit.status == this.filters.status){
                            // console.log(JSON.stringify(visit));
                            visit.filtered = false;
                        }else{
                            visit.filtered = true;
                        }
                    }
                }
            }

        }

        
       
    }

    clearFilters(){
        console.log(this.filters);
        this.filters.start = '';
        this.filters.end = '';
        this.filters.status = '';
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

    fetchAppointments(){
        this.appointments = [];    
        this.loading = true;
        getAppointments({
            centerId: this.selectedCenterId,
            appointmentDay: this.selectedDate
        }).then(async appointments =>{
            for(let i=0;i<appointments.length;i++){
                //generate appointment links
                appointments[i].link = await this[NavigationMixin.GenerateUrl]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: appointments[i].Id,
                        actionName: 'view',
                    }
                }).then((url) => {
                    return url;
                }).catch(err => {
                    console.error(err.body.message);
                });
                // console.log(appointments[i]);
            }

            console.log(appointments);
            this.appointments = appointments;
        }).catch(err =>{
            console.error(err.body.message);
        }).finally(()=>{
            this.loading = false;
        });
    }

    changeCenter(event){
        this.selectedCenterId = event.detail.value;
        this.dateDisabled = false;
    }

    changeDate(event){
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



}