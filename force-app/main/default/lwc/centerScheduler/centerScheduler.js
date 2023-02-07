import { LightningElement, track } from 'lwc';
import getCenters from '@salesforce/apex/CenterScheduleController.getCenters';

export default class CenterScheduler extends LightningElement {

    @track selectedCenterId;
    @track selectedDate
    centers = [];

    @track showFilters=false;
    @track show = false;
    @track dateDisabled = true;

    get appointments(){
        return [
            {
                key:1,
                time: "8:00 AM",
                available: 3,
                filled: 2,
                donors:[
                    {key:1,initials:'KK', icon: 'custom:custom92'},
                    {key:2,initials:'JK', icon: 'custom:custom71'},
                ]
            },
            {
                key:2,
                time: "8:10 AM",
                available: 5,
                filled: 0,
                donors:[

                ]
            },
            {
                key:3,
                time: "8:20 AM",
                available: 0,
                filled: 5,
                donors:[
                    {key:1,initials:'WD', icon: 'custom:custom92'},
                    {key:2,initials:'ZX', icon: 'custom:custom92'},
                    {key:3,initials:'WD', icon: 'custom:custom88'},
                    {key:4,initials:'ZX', icon: 'custom:custom79'},
                    {key:5,initials:'ZX', icon: 'custom:custom63'},
                ]
            },
            {
                key:4,
                time: "8:30 AM",
                available: 2,
                filled: 2,
                donors:[
                    {key:1,initials:'RR', icon: 'custom:custom90'},
                    {key:2,initials:'GG', icon: 'custom:custom91'},
                ]
            },
        ];
    }

    showPopover() {
        this.show = !this.show;
    }

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
        // alert('changed to ' + this.selectedCenterId);
        this.dateDisabled = false;
    }

    changeDate(event){
        this.selectedDate = event.detail.value;
        alert('changed to ' + this.selectedDate);

    }

}