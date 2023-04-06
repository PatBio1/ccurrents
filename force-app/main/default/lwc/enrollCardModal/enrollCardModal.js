import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningModal from 'lightning/modal';

export default class EnrollCardModal extends LightningModal {
    cardPackageId;
    
    get isInputInvalid() {
        return (!this.cardPackageId);
    }

    handleCardPackageIdChange(event) {
        this.cardPackageId = event.detail.value;
    }

    handleSubmitCardEnrollment() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Card enrollment submitted',
            variant: 'success'
        }));
        this.close("success")
    }
}