import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import labels from 'c/labelService';
import util from 'c/util';
import getNotifications from '@salesforce/apex/NotificationsController.getNotifications';

export default class Notifications extends NavigationMixin(LightningElement) {

    labels = labels;
    loading = true;
    notifications = [];

    connectedCallback() {
        this.loadNotifications();
    }

    loadNotifications() {
        this.loading = true;

        getNotifications().then(response => {
            console.log('getNotifications response', response);

            this.notifications = response;
        }).catch((error) => {
            util.showToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    onNotificationClick(event) {
        let index = event.currentTarget.dataset.index;
        let notification = this.notifications[index];

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: notification.id,
                actionName: 'view'
            }
        });
    }

}