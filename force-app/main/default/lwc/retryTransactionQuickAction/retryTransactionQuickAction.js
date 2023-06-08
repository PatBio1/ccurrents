import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { updateRecord } from 'lightning/uiRecordApi';

import markTransactionForRetry from '@salesforce/apex/TransactionActionController.markTransactionForRetry';

export default class RetryTransactionQuickAction extends LightningElement {
    @api recordId;

    @api async invoke() {
        if (!this.recordId) {
            console.error('No recordId provided');
            return;
        }

        try {
            let transactionRecord = await markTransactionForRetry({ transactionId: this.recordId });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Transaction marked for retry, this will be processed in the next AddFundsBatchable job run.',
                variant: 'success'
            }));

            updateRecord({ fields: { ...transactionRecord } });
        } catch (error) {
            console.error(error);
        }
    }
}