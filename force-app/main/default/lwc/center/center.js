import { api, track, LightningElement } from 'lwc';
import labels from 'c/labelService';
import getCenter from '@salesforce/apex/CenterController.getCenter';

export default class Center extends LightningElement {

    labels = labels;
    currentCenterId;
    loading = true;
    loaded = false;
    @track center = {};

    @api backLabel;

    @api get centerId() {
        return this.currentCenterId;
    }
    set centerId(value) {
        this.currentCenterId = value;

        this.loadCenter();
    }

    get welcomeVideoUrl() {
        return `https://www.youtube.com/embed/${labels.welcomeToWestmoreVideoId}?controls=0`;
    }

    loadCenter() {
        this.loading = true;

        const request = {
            centerId: this.currentCenterId
        };

        console.log('getCenter request', JSON.stringify(request));

        getCenter(request).then(response => {
            console.log('getCenter response', response);
            this.center = response;
            this.loaded = true;
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

}