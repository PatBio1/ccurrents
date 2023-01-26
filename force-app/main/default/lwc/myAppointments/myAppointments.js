import { LightningElement } from 'lwc';
import labels from 'c/labelService';
import getVisits from '@salesforce/apex/SchedulerController.getVisits';

export default class MyRewards extends LightningElement {

    labels = labels;
    visits = [];
    scheduledView = 'list';
    pastView = 'list'

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

        const request = {
        };

        console.log('request', JSON.stringify(request));

        getVisits(request).then(response => {
            console.log('response', response);
            this.visits = response;
        }).catch((error) => {
            console.log(error);
            this.loading = false;
        });
    }

    onScheduledListButtonClick() {
        this.scheduledView = 'list';
    }

    onScheduledCalendarButtonClick() {
        this.scheduledView = 'calendar';
    }

}