import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { updateRecord } from 'lightning/uiRecordApi';

import markTransactionAsManualPayment from '@salesforce/apex/TransactionActionController.markTransactionAsManualPayment';

export default class ManualPaymentTransactionQuickAction extends LightningElement {
    @api recordId;

    @api async invoke() {
        if (!this.recordId) {
            console.error('No recordId provided');
            return;
        }

        try {
            let transactionRecord = await markTransactionAsManualPayment({ transactionId: this.recordId });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Transaction marked as manual payment and has been set to \'Complete\'.',
                variant: 'success'
            }));

            updateRecord({ fields: { ...transactionRecord } });
        } catch (error) {
            console.error(error);
        }
    }
}