import { wire, LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';
import isGuest from '@salesforce/user/isGuest';
import userId from '@salesforce/user/Id';
import userSmallPhotoUrl from '@salesforce/schema/User.SmallPhotoUrl';
import logoutModal from 'c/logoutModal';
import labels from 'c/labelService';

export default class Menu extends NavigationMixin(LightningElement) {

    isGuest = isGuest;
    labels = labels;

    photoUrl;

    @wire(getRecord, { recordId: userId, fields: [userSmallPhotoUrl]}) 
    userDetails({error, data}) {
        if (data) {
            this.photoUrl = data.fields.SmallPhotoUrl.value;
        }
    }

    onHamburgerClick() {
        logoutModal.open();
    }

    onNotificationsClick() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Notifications__c'
            }
        });
    }

    onPhotoClick() {
    }

}