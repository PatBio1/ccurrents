import { LightningElement } from 'lwc';
import labels from 'c/labelService';
import util from 'c/util';

export default class Support extends LightningElement {

    labels = labels;
    message;

    get messageValid() {
        return (
            util.isNotBlank(this.message)
        );
    }

    onMessageChange(event) {
        this.message = event.detail.value;
    }

    onSubmitButtonClick() {
        this.message = '';
    }

}