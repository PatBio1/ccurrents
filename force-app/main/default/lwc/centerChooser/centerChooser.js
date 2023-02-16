import { track, LightningElement } from 'lwc';
import ChangeLocationModal from 'c/changeLocationModal';
import labels from 'c/labelService';
import getCenters from '@salesforce/apex/CenterController.getCenters';

// Center of the United States.
const DEFAULT_LATITUDE = 39.123944;
const DEFAULT_LONGITUDE = -94.757340;
const DEFAULT_POSTAL_CODE = '66112';

export default class CenterChooser extends LightningElement {

    labels = labels;
    loading = true;
    centersLoaded = false;
    @track centers = [];
    showCenter = false;
    location = {
        isCurrent: false,
        postalCode: DEFAULT_POSTAL_CODE,
        latitude: DEFAULT_LATITUDE,
        longitude: DEFAULT_LONGITUDE
    };
    @track centerToView = {};

    get centerSelected() {
        return this.centers.some((center) => {
            return center.selected;
        });
    }

    get resultsFor() {
        if (this.location.isCurrent) {
            return labels.myLocation;
        } else {
            return this.location.postalCode;
        }
    }

    connectedCallback() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition((position) => {
                this.location.isCurrent = true;
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

            this.centersLoaded = true;
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

    onChangeButtonClick() {
        ChangeLocationModal.open({
            size: 'small',
            postalCode: this.location.postalCode
        }).then((location) => {
            console.log('modal',location);

            // Reload centers if a new location was selected.
            if (location !== undefined && (this.location.isCurrent || this.location.postalCode != location.postalCode)) {
                this.location.isCurrent = false;
                this.location.postalCode = location.postalCode;
                this.location.latitude = location.latitude;
                this.location.longitude = location.longitude;

                this.loadCenters();
            }
        });
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