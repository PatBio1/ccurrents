import { LightningElement } from 'lwc';
import deleteProfileModal from 'c/deleteProfileModal';
import constants from 'c/constants';
import labels from 'c/labelService';
import util from 'c/util';
import getProfile from '@salesforce/apex/ProfileController.getProfile';
import changeProfile from '@salesforce/apex/ProfileController.changeProfile';
import hasFutureVisit from '@salesforce/apex/SchedulerController.hasFutureVisit';

export default class MyProfile extends LightningElement {

    labels = labels;
    prefixOptions = [
        {label: 'Mr.', value: 'Mr.'},
        {label: 'Ms.', value: 'Ms.'},
        {label: 'Mrs.', value: 'Mrs.'},
        {label: 'Dr.', value: 'Dr.'},
        {label: 'Prof.', value: 'Prof.'}
    ];
    suffixOptions = constants.suffixOptions;
    stateOptions = constants.stateOptions;
    loading = true;
    profile = {};
    changedProfile = {};
    isEditing = false;

    get profileValid() {
        return (
            util.isNotBlank(this.profile.firstName) &&
            util.isNotBlank(this.profile.lastName)
        );
    }

    connectedCallback() {
        getProfile().then(response => {
            console.log('getProfile response', response);
            this.profile = response;
        }).catch((error) => {
            util.showToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    onEditClick() {
        this.loading = true;

        hasFutureVisit().then(response => {
            if (response === true) {
                this.changedProfile = Object.assign({}, this.profile);

                this.isEditing = true;
            } else {
                util.showToast(this, 'error', labels.error, labels.profileChangeNoVisit);
            }
        }).catch((error) => {
            util.showToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    onFieldChange(event) {
        let field = event.target?.dataset?.field;

        this.changedProfile[field] = event.detail?.value;
    }

    onCancelButtonClick() {
        this.isEditing = false;
    }

    onSaveChangesButtonClick() {
        if (util.isBlank(this.changedProfile.height)) {
            this.changedProfile.height = null;
        }

        if (util.isBlank(this.changedProfile.weight)) {
            this.changedProfile.weight = null;
        }

        const request = {
            profile: this.changedProfile
        };

        console.log('changeProfile request', JSON.stringify(request));

        changeProfile(request).then(response => {
            this.isEditing = false;
            util.showToast(this, 'success', labels.success, response);
        }).catch((error) => {
            util.showToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    onDeleteProfileButtonClick() {
        deleteProfileModal.open({
            size: 'small',
            lastName: this.profile.lastName
        }).then(() => {
        });
    }

}