import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningModal from 'lightning/modal';

import linkPaymentCard from '@salesforce/apex/CenterScheduleController.linkPaymentCard';

export default class EnrollCardModal extends LightningModal {
    @api donorId;

    cardPackageId;
    initalPIN;
    loading = false;
    blockExistingCards = false;
    
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
        let linkPaymentCardResult;
        
        try {
            this.loading = true;
            linkPaymentCardResult = await linkPaymentCard({ cardId: this.cardPackageId, donorId: this.donorId, initalPIN: this.initalPIN, blockCards: this.blockExistingCards });
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

        if (linkPaymentCardResult) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Card enrollment submitted',
                variant: 'success'
            }));
        } else {
            // As of writing, the only way this will return null is if a processing code is returned
            // Normal errors will throw an exception
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Card enrollment is still processing, contact Onbe with the tranasction id on the payment method to verify enrollment.',
                variant: 'error'
            }));
        }
        
        this.close("success")
    }

    handleBlockExistingCardsChange(event) {
        this.blockExistingCards = event.detail.checked;
    }
}