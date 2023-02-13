import { api } from "lwc";
import LightningModal from "lightning/modal";

export default class CreateScheduleModal extends LightningModal {
    @api mascots;
    startDate;
    endDate;
    appointmentTier;
    loyaltyTier;
    intervalsPerHour = 0;
    slotsPerInterval = 0;

    
    // handle the event from the visual picker component
    handleSelect(event) {
        this.selectedMascot = event.detail;
    }
    
    handleConfirm() {
        // alert('hey now');
        // Close the Modal
        this.close();
    }

    clearInput(){
        this.startDate = null;
        this.endDate= null;
        this.appointmentTier = null;
        this.loyaltyTier = null;
        this.intervalsPerHour = 0;
        this.slotsPerInterval = 0;
    }

    get inputDisabled(){
        if(this.startDate == null ||  this.endDate == null){
            return false;
        }
        return true;
    }
}