import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningModal from 'lightning/modal';

import cancelDonorActivePayment from '@salesforce/apex/CancelCardController.cancelDonorActivePayment';

export default class LostMyCardModal extends NavigationMixin(LightningModal) {
    isLoading = false;
    
    navigateToScheduleAppointment(event) {
        this.navigateToCommunityPage('schedule');
    }

    navigateToCommunityPage(pageName) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                pageName: pageName
            }
        });
        
        this.close("success");
    }

    async handleCancelCardImmediately() {
        this.isLoading = true;
        
        try {
            await cancelDonorActivePayment();

            this.dispatchEvent(new ShowToastEvent({
                title: 'Card Cancelled',
                message: 'Your card has been cancelled.',
                variant: 'success',
                mode: 'dismissable'
            }));

            this.dispatchEvent(new CustomEvent('cardcancelled'));
            this.close("success");
        } catch(e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Error cancelling card - ' + e.body.message,
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }
}