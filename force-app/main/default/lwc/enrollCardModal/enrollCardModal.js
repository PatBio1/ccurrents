import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningModal from 'lightning/modal';

import linkPaymentCard from '@salesforce/apex/CenterScheduleController.linkPaymentCard';

export default class EnrollCardModal extends LightningModal {
    @api donorId;
    cardPackageId;
    
    get isInputInvalid() {
        return (!this.cardPackageId);
    }

    handleCardPackageIdChange(event) {
        this.cardPackageId = event.detail.value;
    }

    async handleSubmitCardEnrollment() {
        try {
            console.log(this.cardPackageId);
            await linkPaymentCard({ cardId: this.cardPackageId, donorId: this.donorId });
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body.message,
                variant: 'error'
            }));

            return;   
        }

        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Card enrollment submitted',
            variant: 'success'
        }));
        this.close("success")
    }
}