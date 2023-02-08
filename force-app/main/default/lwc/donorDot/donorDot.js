import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class DonorDot extends NavigationMixin(LightningElement)  {

    @track show = false;
    @api initials;
    @api icon = 'standard:account';
    @api donor;
    @api appointment;
    donorLink;
    visitLink;
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
                recordId: this.donor.visitId,
                actionName: 'view',
            },
        }).then((url) => {
            this.visitLink = url;
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

    visitClick(){
        window.open(this.visitLink);
    }
 
}