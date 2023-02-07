import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class DonorDot extends NavigationMixin(LightningElement)  {

    @track show = false;
    @api initials;
    @api icon = 'standard:account';
    @api donor;
    donorLink;

    connectedCallback() {
        // Generate a URL to a User record page
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
 
}