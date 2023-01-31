import { LightningElement } from 'lwc';
import getCenters from '@salesforce/apex/CenterScheduleController.getCenters';

export default class CenterScheduler extends LightningElement {

    selectedCenterId;
    centers = [];

    connectedCallback() {
        this.loadCenters();
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