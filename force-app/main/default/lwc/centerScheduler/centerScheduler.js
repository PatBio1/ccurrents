import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCenters from '@salesforce/apex/CenterScheduleController.getCenters';
import getAppointments from '@salesforce/apex/CenterScheduleController.getAppointments';
import ChangeVisitAppointment from '@salesforce/apex/CenterScheduleController.changeVisitAppointment';
import CreateScheduleModal from "c/createScheduleModal";
import DonorDot from "c/donorDot";

export default class CenterScheduler extends NavigationMixin(LightningElement) {

    @track selectedCenterId;
    @track selectedDate
    @track appointments;
    centers = [];

    @track showFilters=false;
    @track show = false;
    @track dateDisabled = true;
    @track loading;

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
        console.log('donor ID: '  + donorId );
        console.log('original appointment ID'  + appointmentId );
        console.log('original visit ID'  + visitId) ;
        console.log('new appointment ID'  + newAppointmentId );
        if(!newAppointmentId){
            this.showToast('Appointment was not rescheduled, please drop it again','Woops!','warning');
            return;
        }
 
        console.log('new appointment time: ' + newOppointmentTime);
        this.loading = true;
        ChangeVisitAppointment({
            visitId, 
            appointmentId : newAppointmentId
        }).then(()=>{
            this.showToast(`for ${donorName} from ${appointmentTime} to ${newOppointmentTime}`, 'Changed Appointment', 'success');
        }).catch(err => {
            this.showToast(err.message,'There was a problem','error');
            console.debug(err);
        }).finally(() =>{
            this.refresh();
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


}