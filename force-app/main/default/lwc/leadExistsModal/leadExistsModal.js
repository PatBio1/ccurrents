import LightningModal from 'lightning/modal';
import { api } from 'lwc';
import labels from 'c/labelService';

export default class LeadExistsModal extends LightningModal {

    @api email;

    labels = labels;

    get intructionsLabel() {
        return labels.formatLabel(labels.leadExistsInstructions, [this.email]);
    }

    onCancelButtonClick() {
        this.close(false);
    }

    onContinueButtonClick() {
        this.close(true);
    }

}