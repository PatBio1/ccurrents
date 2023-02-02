import { api, track, LightningElement } from 'lwc';
import labels from 'c/labelService';
import util from 'c/util';
import upsertLead from '@salesforce/apex/SchedulerController.upsertLead';
import createUser from '@salesforce/apex/SchedulerController.createUser';
import assignPermissionSet from '@salesforce/apex/SchedulerController.assignPermissionSet';

export default class ClinicChooser extends LightningElement {

    labels = labels;
    currentPage = 'Basic Profile';
    @track profile = {};

    @api center;

    get showBasicProfile() {
        return (this.currentPage === 'Basic Profile');
    }

    get showAddress() {
        return (this.currentPage === 'Address');
    }

    get showPassword() {
        return (this.currentPage === 'Password');
    }

    get centerSelected() {
        return true;
    }

    get suffixOptions() {
        return [
            {label: 'Jr', value: 'Jr'},
            {label: 'II', value: 'II'},
            {label: 'Sr', value: 'Sr'},
            {label: 'III', value: 'III'},
            {label: 'IV', value: 'IV'},
            {label: 'V', value: 'V'},
        ];
    }

    get basicProfileValid() {
        return (
            util.isNotBlank(this.profile.firstName) &&
            util.isNotBlank(this.profile.lastName) &&
            util.isNotBlank(this.profile.email) &&
            util.isNotBlank(this.profile.mobilePhone)
        );
    }

    renderedCallback() {
        console.log('render center', JSON.stringify(this.center));
    }

    onFieldChange(event) {
        let field = event.target?.dataset?.field;

        this.profile[field] = event.detail?.value;
    }

    onBackButtonClick() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    onBasicProfileNextButtonClick() {
        const request = {
            profile: this.profile
        };

        console.log('upsertLead request', JSON.stringify(request));

        upsertLead(request).then(response => {
            console.log('upsertLead response', response);
            this.profile.id = response;

            this.currentPage = 'Address';
        }).catch((error) => {
            console.log(error);
        });
    }

    onAddressNextButtonClick() {
        const request = {
            profile: this.profile
        };

        console.log('upsertLead request', JSON.stringify(request));

        upsertLead(request).then(response => {
            console.log('upsertLead response', response);

            this.currentPage = 'Password';
        }).catch((error) => {
            console.log(error);
        });
    }

    onPasswordNextButtonClick() {
        this.profile.centerId = this.center.id;

        const request = {
            profile: this.profile
        };

        console.log('createUser request', JSON.stringify(request));

        createUser(request).then(response => {
            console.log('createUser response', response);

            this.assignPermissions(response);
        }).catch((error) => {
            console.log(error);
        });
    }

    onNextButtonClick() {
    }

    assignPermissions(userId) {
        const request = {
            userId: userId
        };

        console.log('assignPermissionSet request', JSON.stringify(request));

        assignPermissionSet(request).then(response => {
        }).catch((error) => {
            console.log(error);
        });
    }

}