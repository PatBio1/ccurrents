import LightningModal from 'lightning/modal';
import { NavigationMixin } from 'lightning/navigation';
import labels from 'c/labelService';
import util from 'c/util';

export default class LogoutModal extends NavigationMixin(LightningModal) {

    labels = labels;

    onCancelButtonClick() {
        this.close();
    }

    onLogoutButtonClick() {
        this.close();

        util.logout(this);
    }

}