import { LightningElement } from 'lwc';
import labels from 'c/labelService';
import createAccount from '@salesforce/apex/SchedulerController.createAccount';
import createUser from '@salesforce/apex/SchedulerController.createUser';
import NextStep from '@salesforce/schema/Opportunity.NextStep';

export default class ClinicChooser extends LightningElement {

    labels = labels;

    get centerSelected() {
        return true;
    }

    onBackButtonClick() {
        this.dispatchEvent(new CustomEvent('back'));
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