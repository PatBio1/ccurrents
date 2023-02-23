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

    
    // handle the event from the visual picker component
    handleSelect(event) {
        this.selectedMascot = event.detail;
    }
    
    handleConfirm() {
        // alert('hey now');
        // Close the Modal
       
        this.createSlots()
        
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

    createSlots(){

        // console.log(`create slots for ${this.centerId} ${this.startDate} ${this.endDate} ${this.this.intervalsPerHour} ${this.slotsPerInterval}`);
        console.log(`create slots for ${this.centerId} `);
        console.log(`from ${this.startDate} `);
        console.log(`until ${this.endDate} `);
        CreateAppointmentSlots({
            centerId : this.centerId,
            startDate: this.startDate,
            endDate: this.endDate,
            intervalsPerHour : this.intervalsPerHour,
            slotsPerInterval : this.slotsPerInterval,
            loyaltyTier : null
        }).then(() => {
            this.showToast('success','success','success');
            this.close();
        }).catch((err) =>{
            console.log(JSON.parse(JSON.stringify(err) ));
            this.showToast(err.body.message,'error','error');
        }).finally(()=>{
            // 
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