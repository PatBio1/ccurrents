import { api, track } from "lwc";
import LightningModal from "lightning/modal";

export default class CreateScheduleModal extends LightningModal {
    @api centerId;
    @track startDate;
    @track endDate;
    @track appointmentTier;
    @track loyaltyTier;
    @track intervalsPerHour = 0;
    @track slotsPerInterval = 0;

    
    // handle the event from the visual picker component
    handleSelect(event) {
        this.selectedMascot = event.detail;
    }
    
    handleConfirm() {
        // alert('hey now');
        // Close the Modal
        console.log(this.centerId);
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