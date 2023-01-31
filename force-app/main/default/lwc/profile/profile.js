import { LightningElement } from 'lwc';
import labels from 'c/labelService';
import upsertLead from '@salesforce/apex/SchedulerController.upsertLead';
import createUser from '@salesforce/apex/SchedulerController.createUser';

export default class ClinicChooser extends LightningElement {

    labels = labels;
    currentPage = 'Basic Profile';
    profile = {};

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

    get basicProfileValid() {
        return true;
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
        const request = {
            profile: this.profile
        };

        console.log('createUser request', JSON.stringify(request));

        createUser(request).then(response => {
            console.log('createUser response', response);
        }).catch((error) => {
            console.log(error);
        });
    }

    onNextButtonClick() {
        //this.dispatchEvent(new CustomEvent('next'));

        this.nextStep('001Dn00000ETrbLIAT');
/*
        const request = {
        };

        console.log('createAccount request', JSON.stringify(request));

        createAccount(request).then(response => {
            console.log('createAccount response', response);

            this.nextStep(response);
        }).catch((error) => {
            console.log(error);
        });
*/
    }

    nextStep(accountId) {
        const request = {
            accountId: accountId
        };

        console.log('createUser request', JSON.stringify(request));

        createUser(request).then(response => {
            console.log('createUser response', response);
        }).catch((error) => {
            console.log(error);
        });
    }

}