import { LightningElement } from 'lwc';
import currencyCode from '@salesforce/i18n/currency';
import labels from 'c/labelService';
import getVisits from '@salesforce/apex/SchedulerController.getVisits';
import MobileAppointmentActionsModal from 'c/mobileAppointmentActionsModal';

export default class MyRewards extends LightningElement {

    labels = labels;
    currencyCode = currencyCode;

    scheduledVisits;
    pastVisits;

    scheduledView = 'list';
    pastView = 'list';

    get hasPastVisits() {
        return this.pastVisits && this.pastVisits.length > 0;
    }

    get hasScheduledVisits() {
        return this.scheduledVisits && this.scheduledVisits.length > 0;
    }

    get scheduledListSelected() {
        return (this.scheduledView === 'list');
    }

    get scheduledCalendarSelected() {
        return (this.scheduledView === 'calendar');
    }

    connectedCallback() {
        this.loadVisits();
    }

    loadVisits() {
        this.loading = true;

        getVisits().then((response) => {
            this.scheduledVisits = response.filter(visit => visit.status === 'Scheduled');
            this.pastVisits = response.filter(visit => visit.status === 'Complete' && (visit.outcome === 'Donation' || visit.outcome === 'No Donation'));
        }).catch((error) => {
            console.log(error);
        }).finally(() => {
            this.loading = false;
        });
    }

    onScheduledListButtonClick() {
        this.scheduledView = 'list';
    }

    onScheduledCalendarButtonClick() {
        this.scheduledView = 'calendar';
    }

    handleOpenVisitActions(event) {
        let targetVisitId = event.currentTarget.dataset.visitId;

        MobileAppointmentActionsModal.open({
            visitId: targetVisitId,

            onvisitcancelled: (event) => {
                this.loadVisits();
            }
        });
    }
}