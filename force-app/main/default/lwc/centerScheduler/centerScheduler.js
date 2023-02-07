import { LightningElement, track } from 'lwc';
import getCenters from '@salesforce/apex/CenterScheduleController.getCenters';
import getAppointments from '@salesforce/apex/CenterScheduleController.getAppointments';

export default class CenterScheduler extends LightningElement {

    @track selectedCenterId;
    @track selectedDate
    @track appointments;
    centers = [];

    @track showFilters=false;
    @track show = false;
    @track dateDisabled = true;

    showPopover() {
        this.show = !this.show;
    }

    connectedCallback() {
        this.loadCenters();
    }

    refresh(){
        this.fetchAppointments();
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
        getAppointments({
            centerId: this.selectedCenterId,
            appointmentDay: this.selectedDate
        }).then(appointments =>{
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

    

}