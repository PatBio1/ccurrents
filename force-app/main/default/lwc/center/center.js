import { api, track, LightningElement } from 'lwc';
import labels from 'c/labelService';
import util from 'c/util';
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
            util.showToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    onBackButtonClick() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    onWatchVideoButtonClick() {
        window.open(this.labels.welcomeToWestmoreVideoId, '_self');
    }

}