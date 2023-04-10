import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import labels from 'c/labelService';
import util from 'c/util';

import createSupportCaseForUser from '@salesforce/apex/SupportController.createSupportCaseForUser';
import fetchSupportContactInformation from '@salesforce/apex/SupportController.fetchSupportContactInformation';

export default class Support extends LightningElement {

    labels = labels;
    message;

    contactInformation;
    isInitialized = false;

    get messageValid() {
        return (
            util.isNotBlank(this.message)
        );
    }

    async renderedCallback() {
        if (!this.isInitialized) {
            this.contactInformation = await fetchSupportContactInformation();
            this.isInitialized = true;
        }
    }

    onMessageChange(event) {
        this.message = event.detail.value;
    }

    async onSubmitButtonClick() {
        try {
            await createSupportCaseForUser({ message: this.message });
        }
        catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Couldn\'t Create Case',
                    message: error.body.message,
                    variant: 'error'
                })
            );

            return;
        }

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Case Created!',
                message: 'Your request has been submitted. We will contact you as soon as we are able.',
                variant: 'success'
            })
        );

        this.message = '';
    }
}