import LightningModal from 'lightning/modal';
import { NavigationMixin } from 'lightning/navigation';
import labels from 'c/labelService';

export default class LogoutModal extends NavigationMixin(LightningModal) {

    labels = labels;

    onCancelButtonClick() {
        this.close();
    }

    onLogoutButtonClick() {
        this.close();
        this[NavigationMixin.Navigate]({
            type: 'comm__loginPage',
            attributes: {
                actionName: 'logout'
            }
        });
    }

}