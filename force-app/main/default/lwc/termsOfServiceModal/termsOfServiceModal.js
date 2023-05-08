import LightningModal from 'lightning/modal';
import labels from 'c/labelService';

export default class TermsOfServiceModal extends LightningModal {

    labels = labels;

    onCancelButtonClick() {
        this.close(false);
    }

    onConfirmButtonClick() {
        this.close(true);
    }

}