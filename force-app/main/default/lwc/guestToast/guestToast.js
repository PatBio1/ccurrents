import { api, LightningElement } from 'lwc';
import util from 'c/util';

const MODE_DISMISSABLE = 'dismissable';
const MODE_PESTER = 'pester';
const MODE_STICKY = 'sticky';

export default class GuestToast extends LightningElement {

    variant;
    title;
    message;
    mode;
    showToast = false;

    @api show(variant = 'info', title = '', message = '', mode = MODE_DISMISSABLE) {
        this.variant = variant;
        this.title = title;
        this.message = message;
        this.mode = mode;

        this.showToast = true;

        if (mode !== MODE_STICKY) {
            setTimeout(() => {
                this.hide();
            }, 3000);
        }
    }

    get isPesterMode() {
        return (this.mode === MODE_PESTER);
    }

    get hasMessage() {
        return util.isNotBlank(this.message);
    }

    get themeClass() {
        return 'slds-notify slds-notify_toast slds-theme_' + this.variant;
    }

    get iconContainerClass() {
        return 'slds-icon_container slds-icon-utility-' + this.variant + ' slds-m-right_small slds-no-flex slds-align-top';
    }

    get iconName() {
        return 'utility:' + this.variant;
    }

    onCloseClick() {
        this.hide();
    }

    hide() {
        this.showToast = false;
    }

}
