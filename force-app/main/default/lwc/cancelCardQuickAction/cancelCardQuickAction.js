import { LightningElement, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getDonorDefaultPaymentMethod from '@salesforce/apex/CancelCardController.getDonorDefaultPaymentMethod';
import cancelPaymentMethod from '@salesforce/apex/CancelCardController.cancelPaymentMethod';

export default class CancelCardQuickAction extends LightningElement {
    recordId;
    isLoading = false;
    isInitialized = false;

    defaultPaymentMethod;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.state.recordId;
        }
    }

    renderedCallback() {
        if (this.recordId && !this.isInitialized) {
            this.isInitialized = true;
            this.isLoading = true;

            this.getDefaultPaymentMethod();
        }
    }

    get hasDefaultPaymentMethod() {
        return this.defaultPaymentMethod && this.defaultPaymentMethod.id;
    }

    get cantConfirmCancel() {
        return (!this.hasDefaultPaymentMethod || this.isLoading);
    }

    async getDefaultPaymentMethod() {
        try {
            this.defaultPaymentMethod = await getDonorDefaultPaymentMethod({ donorId: this.recordId });
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Fetch Error',
                message: 'Fetch Payment Method Error - ' + error.body.message,
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    async handleConfirmCancel(event) {
        try {
            this.isLoading = true;

            await cancelPaymentMethod({ paymentMethodId: this.defaultPaymentMethod.id });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Payment Method Cancelled',
                message: 'The default payment method has been successfully cancelled! Any remaining balance has been credited to the donor.',
                variant: 'success'
            }));

            this.handleCancelModal();
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Cancel Payment Method Error',
                message: 'The following error occurred while cancelling the payment method: ' + error.body.message,
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    handleCancelModal(event) {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}