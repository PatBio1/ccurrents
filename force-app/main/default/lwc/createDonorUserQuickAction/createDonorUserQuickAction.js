import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getCenters from '@salesforce/apex/CenterController.getCenters';
import queueCreateUserFromScheduler from '@salesforce/apex/ProfileController.queueCreateUserFromScheduler';

const DEFAULT_LATITUDE = 39.123944;
const DEFAULT_LONGITUDE = -94.757340;

const SUPPORTED_LANGUAGE_OPTIONS = [
    { label: 'English', value: 'en_US' },
    { label: 'Spanish', value: 'es_US' }
];

export default class CreateDonorUserQuickAction extends LightningElement {
    @api recordId;
    
    isLoading = false;

    centerOptions;
    selectedCenterId;

    languageOptions = SUPPORTED_LANGUAGE_OPTIONS;
    selectedLanguage;

    get cantCreateUser() {
        return !this.selectedCenterId || !this.selectedLanguage;
    }

    connectedCallback() {
        this.loadCenters();
    }

    async loadCenters() {
        try {
            this.isLoading = true;

            // We don't care about distance in this flow, just pass default lat/long.
            this.centerOptions = await getCenters({ 
                latitude: DEFAULT_LATITUDE,
                longitude: DEFAULT_LONGITUDE 
            });

            if (this.centerOptions && this.centerOptions.length > 0) {
                this.centerOptions = this.centerOptions.map((center) => {
                    return {
                        label: center.name,
                        value: center.id
                    }
                });
            }
        } catch (error) {
            console.error('getCenters Error', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleSelectCenter(event) {
        this.selectedCenterId = event.detail.value;
    }

    handleSelectLanguage(event) {
        this.selectedLanguage = event.detail.value;
    }

    async handleCreateUser() {
        try {
            this.isLoading = true;

            await queueCreateUserFromScheduler({
                centerId: this.selectedCenterId,
                accountId: this.recordId,
                language: this.selectedLanguage
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Creation of the user has been queued successfully.',
                variant: 'success'
            }));

            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            console.error('queueCreateUserFromScheduler Error', error);

            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Error while queuing the user creation - ' + error.body.message,
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    handleCancelAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}