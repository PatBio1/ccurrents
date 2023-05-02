import LightningModal from 'lightning/modal';
import { api } from 'lwc';
import labels from 'c/labelService';

export default class DeleteProfileConfirmModal extends LightningModal {

    @api isDelete;

    labels = labels;

    get confirmationLabel() {
        return (this.isDelete ? labels.confirmDeleteProfile : labels.confirmInactivateProfile);
    }

    onCancelButtonClick() {
        this.close(false);
    }

    onConfirmButtonClick() {
        this.close(true);
    }

}