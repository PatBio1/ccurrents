import { track, LightningElement } from 'lwc';
import labels from 'c/labelService';
import getCenters from '@salesforce/apex/CenterController.getCenters';

// Center of the United States.
const DEFAULT_LATITUDE = 39.123944;
const DEFAULT_LONGITUDE = -94.757340;

export default class CenterChooser extends LightningElement {

    labels = labels;
    loading = true;
    @track centers = [];
    showCenter = false;
    location = {
        latitude: DEFAULT_LATITUDE,
        longitude: DEFAULT_LONGITUDE
    };
    @track centerToView = {};

    get centerSelected() {
        return this.centers.some((center) => {
            return center.selected;
        });
    }

    connectedCallback() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition((position) => {
                this.location.latitude = position.coords.latitude;
                this.location.longitude = position.coords.longitude;

                this.loadCenters();
            },
            () => {
                // Denied geolocation - use default location.
                this.loadCenters();
            });
        } else {
            // No geolocation - use default location.
            this.loadCenters();
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
            // TODO - add error handling
            console.log(error);
        }).finally(() => {
            this.loading = false;
        });
    }

    onBackButtonClick() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    onViewCenterClick(event) {
        let index = event.target.dataset.index;
        this.centerToView = this.centers[index];

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
        const selectedCenter = this.centers.find((center) => center.selected);

        this.dispatchEvent(new CustomEvent('next', {detail: {selectedCenter: selectedCenter}}));
    }

}