import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import LightningModal from 'lightning/modal';

export default class LostMyCardModal extends NavigationMixin(LightningModal) {
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

    handleCancelCardImmediately() {
        // Show a test toast message
        const evt = new ShowToastEvent({
            title: 'Card Cancelled',
            message: 'Your card has been cancelled. (Testing only for now)',
            variant: 'success',
            mode: 'dismissable'
        });
        
        this.dispatchEvent(evt);
        this.close("success");
    }
}