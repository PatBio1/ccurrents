import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LOCALE from '@salesforce/i18n/locale';
import CURRENCY from '@salesforce/i18n/currency';

import getBaseVisitExceptionPaymentInfo from '@salesforce/apex/ExceptionPaymentController.getBaseVisitExceptionPaymentInfo';
import createExceptionPayment from '@salesforce/apex/ExceptionPaymentController.createExceptionPayment';

const EXCEPTION_RATE_SELECTION_SCREEN = 'exceptionRateSelection';
const EXCEPTION_PAYMENT_CONFIRMATION_SCREEN = 'exceptionPaymentConfirmation';
const LIMIT_EXCEED_ERROR_COLOR = '#f76f6f';

export default class VisitExceptionPayment extends LightningElement {
    _recordId;

    isLoading = false;
    currentScreen = EXCEPTION_RATE_SELECTION_SCREEN;

    baseVisitExceptionPaymentInfo;
    selectedRateId;

    userCurrency = CURRENCY;

    @api set recordId(value) {
        this._recordId = value;
        this.isLoading = true;

        this.getBaseVisitExceptionPaymentInfo();
    }

    get hasCenterDayLimit() {
        return this.hasBaseVisitExceptionPaymentInfo && this.baseVisitExceptionPaymentInfo.visitDayRemainingLimit;
    }

    get hasCenterIndividualLimit() {
        return this.hasBaseVisitExceptionPaymentInfo && this.baseVisitExceptionPaymentInfo.visitIndividualLimit;
    }

    get hasCenterLimits() {
        return this.hasCenterDayLimit || this.hasCenterIndividualLimit;
    }

    get centerDayLimitBackgroundStyle() {
        if (
            !this.hasBaseVisitExceptionPaymentInfo ||
            !this.baseVisitExceptionPaymentInfo.visitDayRemainingLimit ||
            !this.selectedRateId ||
            this.selectedExceptionRateInfo.amount <= this.baseVisitExceptionPaymentInfo.visitDayRemainingLimit
        ) {
            return '';
        }

        return `background: ${LIMIT_EXCEED_ERROR_COLOR}`;
    }
    
    get centerIndividualLimitBackgroundStyle() {
        if (
            !this.hasBaseVisitExceptionPaymentInfo ||
            !this.baseVisitExceptionPaymentInfo.visitIndividualLimit ||
            !this.selectedRateId ||
            this.selectedExceptionRateInfo.amount <= this.baseVisitExceptionPaymentInfo.visitIndividualLimit
        ) {
            return '';
        }

        return `background: ${LIMIT_EXCEED_ERROR_COLOR}`;
    }

    get recordId() {
        return this._recordId;
    }

    get isValidForExceptionPayment() {
        if (!this.baseVisitExceptionPaymentInfo) {
            return false;
        }

        let visitDateTime = new Date(this.baseVisitExceptionPaymentInfo.visitDatetime);
        let currentDateTime = new Date();

        return (visitDateTime.toLocaleDateString() === currentDateTime.toLocaleDateString());
    }

    get hasBaseVisitExceptionPaymentInfo() {
        return this.baseVisitExceptionPaymentInfo;
    }
    
    get hasExceptionRateInfo() {
        // return false;
        return (
            this.hasBaseVisitExceptionPaymentInfo && 
            this.baseVisitExceptionPaymentInfo.availableExceptionPaymentTypes && 
            this.baseVisitExceptionPaymentInfo.availableExceptionPaymentTypes.length
        );
    }

    get exceptionRateOptions() {
        const formatter = new Intl.NumberFormat(LOCALE, {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });

        return this.baseVisitExceptionPaymentInfo.availableExceptionPaymentTypes.map((exceptionRateInfo) => {
            return {
                label: `${exceptionRateInfo.description} - ${formatter.format(exceptionRateInfo.amount)}`,
                value: exceptionRateInfo.id
            };
        });
    }

    get isScreenInputInvalid() {
        return !this.selectedRateId;
    }

    get isExceptionRateSelectionScreen() {
        return this.currentScreen === EXCEPTION_RATE_SELECTION_SCREEN;
    }

    get isExceptionPaymentConfirmationScreen() {
        return this.currentScreen === EXCEPTION_PAYMENT_CONFIRMATION_SCREEN;
    }

    get selectedExceptionRateInfo() {
        if (!this.selectedRateId) {
            return null
        };

        return this.baseVisitExceptionPaymentInfo.availableExceptionPaymentTypes.find((exceptionRateInfo) => {
            return exceptionRateInfo.id === this.selectedRateId;
        });
    }

    async getBaseVisitExceptionPaymentInfo() {
        this.baseVisitExceptionPaymentInfo = await getBaseVisitExceptionPaymentInfo({ targetVisitId: this._recordId });
        console.log(this.baseVisitExceptionPaymentInfo);

        this.isLoading = false;
    }

    handleChangeRateSelection(event) {
        this.selectedRateId = event.detail.value;
    }

    handleNavigateBackToRateSelection(event) {
        this.currentScreen = EXCEPTION_RATE_SELECTION_SCREEN;
    }

    handleNavigateToPaymentConfirmation(event) {
        this.currentScreen = EXCEPTION_PAYMENT_CONFIRMATION_SCREEN;
    }

    async handleConfirmExceptionPayment(event) {
        this.isLoading = true;

        try {
            await createExceptionPayment({
                donorId: this.baseVisitExceptionPaymentInfo.visitDonorId,
                visitId: this.recordId,
                exceptionRateId: this.selectedRateId
            });
        } catch(e) {
            this.isLoading = false;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Create Payment Failed',
                message: e.body.message,
                variant: 'error'
            }));
            return;
        }

        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Exception payment created successfully',
            variant: 'success'
        }));
        this.closeActionModal();
    }

    closeActionModal(event) {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}