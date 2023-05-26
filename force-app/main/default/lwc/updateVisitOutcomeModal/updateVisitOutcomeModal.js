import { wire, api } from 'lwc';
import LightningModal from 'lightning/modal';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import VISIT_OBJECT from '@salesforce/schema/Visit__c';
import OUTCOME_FIELD from '@salesforce/schema/Visit__c.Outcome__c';

import updateVisitOutcome from '@salesforce/apex/CenterScheduleController.updateVisitOutcome';

const EXCLUDED_OUTCOMES = [
    'Canceled',
    'Rescheduled'
];

export default class UpdateVisitOutcomeModal extends LightningModal {
    @api visitId;
    
    @wire(getObjectInfo, { objectApiName: VISIT_OBJECT })
    visitObjectInfo;

    @wire(getPicklistValues, { recordTypeId: '$visitObjectInfo.data.defaultRecordTypeId', fieldApiName: OUTCOME_FIELD })
    visitOutcomePicklistValues;

    selectedVisitOutcome;
    loading = false;

    get inputNotValid() {
        return !this.selectedVisitOutcome;
    }

    get visitOutcomePicklistOptionData() {
        let options = [];

        if (this.visitOutcomePicklistValues.data) {
            options = this.visitOutcomePicklistValues.data.values
                .filter(option => !EXCLUDED_OUTCOMES.includes(option.value))
                .map(option => {
                    return {
                        label: option.label,
                        value: option.value
                    }
                });
        }

        return options;
    }

    handleUpdateSelectedOutcome(event) {
        this.selectedVisitOutcome = event.detail.value;
    }

    async handleSaveOutcomeUpdate(event) {
        this.loading = true;

        try {
            await updateVisitOutcome({ visitId: this.visitId, outcome: this.selectedVisitOutcome });
        } catch(e) {
            // Toast the error
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error updating visit outcome',
                    message: e.body.message,
                    variant: 'error'
                })
            );
        } finally {
            this.loading = false;
        }

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Visit Updated!',
                message: `The visit outcome has been updated to ${this.selectedVisitOutcome}.`,
                variant: 'success'
            })
        );

        this.dispatchEvent(new CustomEvent('visitoutcomeupdated'));
        this.close();
    }

    handleCloseModal(event) {
        this.close();
    }
}