import { LightningElement, track } from 'lwc';
import getCenters from '@salesforce/apex/CenterScheduleController.getCenters';

export default class CenterScheduler extends LightningElement {

    selectedCenterId;
    centers = [];

    @track showFilters=false;

    connectedCallback() {
        this.loadCenters();
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

        const request = {
        };

        console.log('request', JSON.stringify(request));

        getCenters(request).then(response => {
            console.log('response', response);
            this.center = response;

            this.loadAppointments();
        }).catch((error) => {
            console.log(error);
            this.loading = false;
        });
    }

    changeCenter(event){
        this.selectedCenterId = event.detail.value;
        alert('changed to ' + this.selectedCenterId);
    }

}