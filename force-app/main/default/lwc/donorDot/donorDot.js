import { LightningElement, track, api } from 'lwc';

export default class DonorDot extends LightningElement {

    @track show = false;
    @api initials;
    @api icon = 'standard:account';

    togglePopover() {
        this.show = !this.show;
    }

    hidePopover() {
        this.show = false;
    }
 
}