import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import TIME_ZONE from '@salesforce/i18n/timeZone';
import getCenters from '@salesforce/apex/CenterScheduleController.getCenters';
import getAppointments from '@salesforce/apex/CenterScheduleController.getAppointments';
import getVisits from '@salesforce/apex/CenterScheduleController.getVisits';
import ChangeVisitAppointment from '@salesforce/apex/CenterScheduleController.changeVisitAppointment';
import CreateScheduleModal from "c/createScheduleModal";
import DonorDot from "c/donorDot";

export default class CenterScheduler extends NavigationMixin(LightningElement) {

    
    @track selectedCenterId;
    @track selectedDate
    @track appointments;
    centers = [];
    tz=TIME_ZONE;

    @track showFilters=false;
    @track show = false;
    @track dateDisabled = true;
    @track loading;

    @track filters = {
        start: '',
        end: ''
    }

    showPopover() {
        this.show = !this.show;
    }

    connectedCallback() {
        this.loadCenters();
        // alert(TIME_ZONE);
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
        });
    }
    
    drop(event){
        console.log('dropped');
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
        // console.log('donor ID: '  + donorId );
        // console.log('original appointment ID'  + appointmentId );
        // console.log('original visit ID'  + visitId) ;
        // console.log('new appointment ID'  + newAppointmentId );
        if(!newAppointmentId){
            this.showToast('Appointment was not rescheduled, please drop it again','Woops!','warning');
            return;
        }
 
        // console.log('new appointment time: ' + newOppointmentTime);
        if(appointmentId == newAppointmentId){
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
                    await getVisits({appointmentId }).then(visits => {
                        appRow.visits = visits;
                    })
                }
                //new row
                if(appRow.Id == newAppointmentId){
                    appRow.visits = [];
                    await getVisits({appointmentId : newAppointmentId}).then(visits => {
                        appRow.visits = visits;
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

    get statuses(){
        return [    
            {label:'bleeding', value:'bleeding'},
            {label:'bled', value:'bled'},
            {label:'dry', value:'dry'}
        ]
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

    applyFilters(){
        //alert(this.filters.start);
        let startTime = this.timeToDate(this.filters.start);
        console.log('startTime',startTime);
         
        let endTime = this.timeToDate(this.filters.end);
        console.log('endTime -> ', endTime);   
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
    }

    clearFilters(){
        console.log(this.filters);
        this.filters.start = '';
        this.filters.end = '';
        for(let i=0;i < this.appointments.length;i++){
            let app = this.appointments[i];
            app.filtered = false;
        }
    }
    changeFilterStart(event){
        this.filters.start =  event.target.value;
        // alert(event.target.value);
    }
    changeFilterEnd(event){
        this.filters.end =  event.target.value;
        // alert(event.target.value);
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
                    console.error(err);
                });
                // console.log(appointments[i]);
            }

            console.log(appointments);
            this.appointments = appointments;
        }).catch(err =>{
            console.error(err);
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

    timeToDate(timestring){
        // take provided time
        // alert(timestring)
        let stringparts = timestring.split(' ')
        let timeparts = stringparts[0].split(':');
        let hours = parseInt(timeparts[0]);
        if(stringparts[1] === 'PM'){
            hours = hours + 12;
        }
        let minutes = timeparts[1];
        // console.log(JSON.stringify(timeparts));
        // apply to current schedule date
       let dateparts  = this.selectedDate.split('-');
    //    console.log(JSON.stringify(dateparts));
       let year = dateparts[0];
       let month = parseInt(dateparts[1]) -1; //month in js offset
       let day = dateparts[2]
    //    alert(month)
        const newDate = new Date(parseInt(year), parseInt(month), parseInt(day), parseInt(hours), parseInt(minutes) );
        // alert(newDate);
        return newDate;
    }



}