import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import { NavigationMixin } from 'lightning/navigation';
import labels from 'c/labelService';
import util from 'c/util';
import deactivateUser from '@salesforce/apex/ProfileController.deactivateUser';
import userId from '@salesforce/user/Id';
import deleteProfileConfirmModal from 'c/deleteProfileConfirmModal';

export default class DeleteProfileModal extends NavigationMixin(LightningModal) {

    labels = labels;
    util = util;

    @api lastName;
    confirmLastName;
    loading = false;
    errorMessage;

    type = 'inactivate';

    get typeOptions() {
        return [
            { label: 'Inactivate my Profile', value: 'inactivate' },
            { label: 'Delete my Information', value: 'delete' }
        ];
    }

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

    onTypeChange(event) {
        this.type = event.detail.value;
    }

    onConfirmLastNameChange(event) {
        this.confirmLastName = event.detail?.value;
        this.errorMessage = undefined;
    }

    onCancelButtonClick() {
        this.close();
    }

    onDeleteButtonClick() {
        const isDelete = (this.type === 'delete');

        deleteProfileConfirmModal.open({
            isDelete: isDelete
        }).then((confirmed) => {
            if (confirmed) {
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
            } else {
                this.close();
            }
        });
    }

}