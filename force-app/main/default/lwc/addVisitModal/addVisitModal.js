import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import searchVisitElgibleDonorByName from '@salesforce/apex/DonorSelector.searchVisitElgibleDonorByName';
import addVisit from '@salesforce/apex/CenterScheduleController.addVisit';

export default class AddVisitModal extends LightningModal {
    @api appointmentSlotId;
    @api appointmentSlotDate;
    @api appointmentSlotTime;
    @api centerId;
    @api hasLoyaltyAvailability;
    @api hasAvailability;

    foundDonors;
    updateSearchTimeout;
    isSearching;
    isLoading;

    get headerLabel() {
        let dateString = (new Date(this.appointmentSlotDate).toLocaleDateString(
            'en-us', { year:"numeric", month:"long", day:"2-digit", weekday:"long", timeZone: "UTC" }
        ));

        return `Add Visit - ${dateString} @ ${this.appointmentSlotTime}`;
    }

    get hasDonorsToDisplay() {
        return (this.foundDonors && this.foundDonors.length > 0);
    }

    handleDonorSearchUpdate(event) {
        if (this.updateSearchTimeout) {
            clearTimeout(this.updateSearchTimeout);
        }

        // Use a setTimeout to ensure a search is only carried out after the user completes typing
        // Reset the timeout everytime the user changes the search term
        this.updateSearchTimeout = setTimeout(this.executeSearch.bind(this), 250);
    }

    async executeSearch() {
        this.isSearching = true;
        this.foundDonors = await searchVisitElgibleDonorByName({ 
            nameSearchString: this.template.querySelector("lightning-input[data-donor-name-search]").value,
            targetVisitDateString: this.appointmentSlotDate,
            allowLoyaltyDonors: this.hasAvailability || this.hasLoyaltyAvailability,
            allowDonors: this.hasAvailability
        });
        
        this.updateSearchTimeout = null;
        this.isSearching = false;
    }

    async handleSelectDonor(event) {
        this.isLoading = true;
        
        try {
            await addVisit({ 
                donorId: event.currentTarget.dataset.donorId,
                appointmentSlotId: this.appointmentSlotId,
                centerId: this.centerId 
            });
        } catch(e) {
            this.dispatchEvent(new ShowToastEvent({
                title: "Visit Create Failure",
                message: `We encountered the following error while trying to create the visit.\t${e.message}`,
                variant: "error"
            }));

            this.isLoading = false;
            return;
        }

        this.dispatchEvent(new ShowToastEvent({
            title: "Visit Created!",
            message: `The visit was successfully created!`,
            variant: "success"
        }));

        this.dispatchEvent(new CustomEvent("visitcreated"));
        this.close("success");
    }
}