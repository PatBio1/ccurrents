import { api, track } from "lwc";
import LightningModal from "lightning/modal";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import CreateAppointmentSlots from '@salesforce/apex/CenterScheduleController.createAppointmentSlots';

export default class CreateScheduleModal extends LightningModal {
    @api centerId;
    @track startDate;
    @track endDate;
    @track appointmentTier;
    @track loyaltyTier;
    @track intervalsPerHour = 1;
    @track slotsPerInterval = 1;
    loading = false;
    
    // handle the event from the visual picker component
    handleSelect(event) {
        this.selectedMascot = event.detail;
    }
    
    handleConfirm() {
        const allValid = [
            ...this.template.querySelectorAll('lightning-input'),
        ].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);
        if (allValid) {
            this.createSlots();
        } else {
            this.showToast('Please update the invalid form entries and try again.','warning','warning');
        }
        
    }

    changeStart(event){
        this.startDate = event.target.value;
    }
    changeEnd(event){
        this.endDate = event.target.value;
    }

    changeIntervalsPerHour(event){
        this.intervalsPerHour = event.target.value;
    }

    changeSlotsPerInterval(event){
        this.slotsPerInterval = event.target.value;
    }


     async clearInput(){
        
        this.startDate = null;
        this.endDate= null;
        this.appointmentTier = null;
        this.loyaltyTier = null;
        this.intervalsPerHour = 1;
        this.slotsPerInterval = 1;
        await this.validate();
    }

    async validate(){
        const allValid = await [
            ...this.template.querySelectorAll('lightning-input'),
        ].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

        
    }

    get inputDisabled(){
        if(this.startDate == null ||  this.endDate == null){
            return false;
        }
        return true;
    }

    get today(){
        var today = new Date();
        var dd = String(today.getDate()).padStart(2, '0');
        var mm = String(today.getMonth() + 1).padStart(2, '0'); //January is 0!
        var yyyy = today.getFullYear();

        today = yyyy + '/' + mm + '/' + dd;
        return today;
    }

    createSlots(){

        this.loading = true;
        CreateAppointmentSlots({
            centerId : this.centerId,
            startDate: this.startDate,
            endDate: this.endDate,
            intervalsPerHour : this.intervalsPerHour,
            slotsPerInterval : this.slotsPerInterval,
            loyaltyTier : null
        }).then(() => {
            this.showToast('success','success','success');
            this.close(this.startDate);
        }).catch((err) =>{
            console.log(JSON.parse(JSON.stringify(err) ));
            this.showToast(err.body.message,'error','error');
        }).finally(()=>{
            this.loading = false;
        });
    }

    showToast(message, title, variant){
        title = (title ? title : '');
        variant = (variant ? variant : 'info');
        message = (message ? message : 'no message');
        this.dispatchEvent(
            new ShowToastEvent({
                message,
                variant,
                title
            })
        );
    }
}