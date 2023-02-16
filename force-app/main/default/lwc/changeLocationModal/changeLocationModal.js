import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import labels from 'c/labelService';
import util from 'c/util';
import getLatLong from '@salesforce/apex/CenterController.getLatLong';

export default class ChangeLocationModal extends LightningModal {

    labels = labels;
    util = util;

    @api postalCode;
    loading = false;
    errorMessage;

    get changeDisabled() {
        return (
            this.loading ||
            util.isBlank(this.postalCode) ||
            this.postalCode.length !== 5
        );
    }

    onPostalCodeChange(event) {
        this.postalCode = event.detail?.value;
        this.errorMessage = undefined;
    }

    onCancelButtonClick() {
        this.close();
    }

    onChangeButtonClick() {
        let postalCodeInput = this.template.querySelector('lightning-input');

        this.loading = true;

        const request = {
            postalCode: postalCodeInput.value
        };

        console.log('request', JSON.stringify(request));

        getLatLong(request).then(response => {
            console.log('response', response);

            if (response) {
                const location = Object.assign(response, {postalCode: request.postalCode});

                this.close(location);
            } else {
                this.errorMessage = labels.invalidZipCode;
            }
        }).catch((error) => {
            // TODO - add error handling
            console.log(error);
        }).finally(() => {
            this.loading = false;
        });
    }

}