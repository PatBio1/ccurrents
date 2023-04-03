import { api, LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningModal from 'lightning/modal';

import createSoonestNextVisitForDonor from '@salesforce/apex/CenterScheduleController.createSoonestNextVisitForDonor';

export default class CreateDonorModal extends LightningModal {
    @api selectedCenter;

    createNewVisit = true;
    isLoading = false;

    get profileCenterObject() {
        return {
            id: this.selectedCenter
        };
    }

    async handleDonorCreationComplete(event) {
        if (this.createNewVisit) {
            await createSoonestNextVisitForDonor({
                donorId: event.detail.donorId,
                centerId: this.selectedCenter
            });
        }

        this.dispatchEvent(new CustomEvent('donorcreated', {
            detail: {
                wasVisitScheduled: this.createNewVisit
            }
        }));

        this.dispatchEvent(new ShowToastEvent({
            title: 'Donor Created',
            message: 'The donor\'s account and user records have been created!',
            variant: 'success'
        }));

        this.close();
    }

    handleCreateNewVisitChange(event) {
        this.createNewVisit = event.detail.checked;
    }

    handleBeginDonorCreate(event) {
        this.isLoading = true;
    }
}