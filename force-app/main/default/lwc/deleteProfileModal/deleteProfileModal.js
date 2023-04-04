import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import { NavigationMixin } from 'lightning/navigation';
import labels from 'c/labelService';
import util from 'c/util';
import deactivateUser from '@salesforce/apex/ProfileController.deactivateUser';
import userId from '@salesforce/user/Id';

export default class DeleteProfileModal extends NavigationMixin(LightningModal) {

    labels = labels;
    util = util;

    @api lastName;
    confirmLastName;
    loading = false;
    errorMessage;

    get confirmationLabel() {
        return labels.formatLabel(labels.deleteProfileConfirmation, ['<strong>' + this.lastName + '</strong>']);
    }

    get deleteDisabled() {
        return (
            this.loading ||
            util.isBlank(this.confirmLastName) ||
            this.lastName.toLowerCase() !== this.confirmLastName.toLowerCase()
        );
    }

    onConfirmLastNameChange(event) {
        this.confirmLastName = event.detail?.value;
        this.errorMessage = undefined;
    }

    onCancelButtonClick() {
        this.close();
    }

    onDeleteButtonClick() {
        this.errorMessage = undefined;
        this.loading = true;

        const request = {
            userId: userId
        };

        console.log('deactivateUser request', JSON.stringify(request));

        deactivateUser(request).then(response => {
            console.log('deactivateUser response', response);

            this.close();

            util.logout(this);
        }).catch((error) => {
            this.errorMessage = util.getFilteredErrorMessage(error);
        }).finally(() => {
            this.loading = false;
        });
    }

}