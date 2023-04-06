import { wire, LightningElement } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import deleteProfileModal from 'c/deleteProfileModal';
import labels from 'c/labelService';
import userId from '@salesforce/user/Id';
import userLastName from '@salesforce/schema/User.LastName';

export default class MyProfile extends LightningElement {

    labels = labels;
    lastName;

    @wire(getRecord, { recordId: userId, fields: [userLastName]}) 
    userDetails({error, data}) {
        if (data) {
            this.lastName = data.fields.LastName.value;
        }
    }

    onDeleteProfileButtonClick() {
        deleteProfileModal.open({
            size: 'small',
            lastName: this.lastName
        }).then(() => {
        });
    }

}