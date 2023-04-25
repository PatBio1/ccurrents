import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import { NavigationMixin } from 'lightning/navigation';

import cancelVisit from '@salesforce/apex/SchedulerController.cancelVisit';
import labels from 'c/labelService';

const SELECT_ACTION_SCREEN_KEY = 'SELECT_ACTION';
const CONFIRM_CANCEL_SCREEN_KEY = 'CONFIRM_CANCEL';

export default class MobileAppointmentActionsModal extends NavigationMixin(LightningModal) {
    @api visitId;

    labels = labels;
    currentScreen = SELECT_ACTION_SCREEN_KEY;

    get displaySelectActionScreen() {
        return (this.currentScreen === SELECT_ACTION_SCREEN_KEY);
    }

    get displayConfirmCancelScreen() {
        return (this.currentScreen === CONFIRM_CANCEL_SCREEN_KEY);
    }

    handleRescheduleVisit(event) {
        this[NavigationMixin.GenerateUrl]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'schedule'
            }
        }).then((response) => {
            window.location.href = `${response}?rescheduleVisitId=${this.visitId}`;
            this.close('success');
        });
    }

    handleInitCancelVisit(event) {
        this.currentScreen = CONFIRM_CANCEL_SCREEN_KEY;
    }

    async handleConfirmCancelVisit(event) {
        try {
            await cancelVisit({ visitId: this.visitId });

            this.dispatchEvent(new CustomEvent('visitcancelled'));
            this.close('success');
        } catch (error) {
            console.error(error);
        }
    }
}