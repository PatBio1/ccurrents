import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class DonorDot extends NavigationMixin(LightningElement)  {

    @track show = false;
    @api initials;
    @api icon = 'standard:account';
    @api donor;
    @api appointment;
    donorLink;
    appointmentLink;
    dotclasses = [
        'slds-m-right_small',
        'donor-icon',
        'scheduled'
    ];

    get classes(){
        return this.dotclasses.join(' ');
    }

    connectedCallback() {
        
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.appointment.Id,
                actionName: 'view',
            },
        }).then((url) => {
            this.appointmentLink = url;
        });

        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.donor.donorId,
                actionName: 'view',
            },
        }).then((url) => {
            this.donorLink = url;
        });
    }

    togglePopover() {
        this.show = !this.show;
    }

    hidePopover() {
        this.show = false;
    }

    donorClick(){
        window.open(this.donorLink);
    }

    appointmentClick(){
        window.open(this.appointmentLink);
    }
 
}