import { LightningElement } from 'lwc';

export default class Center extends LightningElement {

    onBackClick() {
        this.dispatchEvent(new CustomEvent('redirect', {detail: {url: '/apex/Scheduler'}}));
    }

}