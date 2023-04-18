import { api, LightningElement } from 'lwc';
import labels from 'c/labelService';
import util from 'c/util';
import viewNotification from '@salesforce/apex/NotificationsController.viewNotification';

export default class Notifications extends LightningElement {

    @api recordId;

    labels = labels;
    loading = true;
    notification = {};

    connectedCallback() {
        this.loadNotification();
    }

    loadNotification() {
        this.loading = true;

        const request = {
            notificationId: this.recordId
        };

        console.log('viewNotification request', JSON.stringify(request));

        viewNotification().then(response => {
            console.log('viewNotification response', response);

            this.notification = response;
        }).catch((error) => {
            util.showToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

}