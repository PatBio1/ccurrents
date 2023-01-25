import { track, LightningElement } from 'lwc';
import labels from 'c/labelService';
import getCenters from '@salesforce/apex/SchedulerController.getCenters';

export default class ClinicChooser extends LightningElement {

    labels = labels;
    @track centers = [];
    showCenter = false;
    location = {};

    get centerSelected() {
        return this.centers.some((center) => {
            return center.selected;
        });
    }

    connectedCallback() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(position => {
                this.location.latitude = position.coords.latitude;
                this.location.longitude = position.coords.longitude;

                console.log('location', this.location);

                this.loadCenters();
            });
        } else {
            console.log('no geolocation!!');
        }
    }

    loadCenters() {
        this.loading = true;

        const request = {
            latitude: this.location.latitude,
            longitude: this.location.longitude
        };

        console.log('request', JSON.stringify(request));

        getCenters(request).then(response => {
            console.log('response', response);
            this.centers = response;
        }).catch((error) => {
            console.log(error);
            this.loading = false;
        });
    }

    onBackButtonClick() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    onViewCenterClick() {
        this.showCenter = true;
    }

    onCenterBackButtonClick() {
        this.showCenter = false;
    }

    onCenterChange(event) {
        let selected = event.target.checked;
        let index = event.target.dataset.index;
        let center = this.centers[index];

        this.centers.forEach((c) => {
            c.selected = false;
        });

        center.selected = selected;
    }

    onNextButtonClick() {
        this.dispatchEvent(new CustomEvent('next'));
    }

}