import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningModal from 'lightning/modal';

import linkPaymentCard from '@salesforce/apex/CenterScheduleController.linkPaymentCard';

export default class EnrollCardModal extends LightningModal {
    @api donorId;

    cardPackageId;
    initalPIN;
    loading = false;
    
    get isInputInvalid() {
        let pinInputField = this.template.querySelector('lightning-input[data-pin-input]');

        let pinAsIntValue = !this.initalPIN ? 0 : parseInt(this.initalPIN);
        let isValidPin = pinInputField?.checkValidity() && !isNaN(pinAsIntValue) && pinAsIntValue >= 1000;

        return (
            !this.cardPackageId || !this.initalPIN || !isValidPin
        );
    }

    handleCardPackageIdChange(event) {
        this.cardPackageId = event.detail.value;
    }

    handlePINChange(event) {
        this.initalPIN = event.detail.value;
    }

    async handleSubmitCardEnrollment() {
        try {
            this.loading = true;
            await linkPaymentCard({ cardId: this.cardPackageId, donorId: this.donorId, initalPIN: this.initalPIN });
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body.message,
                variant: 'error'
            }));

            return;   
        } finally {
            this.loading = false;
        }

        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Card enrollment submitted',
            variant: 'success'
        }));
        this.close("success")
    }
}