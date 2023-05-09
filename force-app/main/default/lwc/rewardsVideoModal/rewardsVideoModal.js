import { LightningElement } from 'lwc';
import LightningModal from 'lightning/modal';

import labels from 'c/labelService';

export default class RewardsVideoModal extends LightningModal {
    labels = labels;

    get modalTitle() {
        return this.labels.rewardsVideoTitle;
    }

    get videoLink() {
        return this.labels.rewardsVideoLink;
    }

    get hasVideoLink() {
        return !!this.videoLink;
    }
}