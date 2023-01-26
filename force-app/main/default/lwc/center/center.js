import { LightningElement } from 'lwc';
import labels from 'c/labelService';

export default class Center extends LightningElement {

    labels = labels;

    onBackButtonClick() {
        this.dispatchEvent(new CustomEvent('back'));
    }

}