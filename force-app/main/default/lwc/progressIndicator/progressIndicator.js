import { api, track, LightningElement } from 'lwc';

export default class ProgressIndicator extends LightningElement {
    @api steps;
    @api currentStep;

    @track items = [];

    connectedCallback() {
        let items = [];

        for (let i = 1; i <= this.steps; i++) {
            const completed = (i < this.currentStep);
            const active = (i == this.currentStep);

            let targetItemClass = "progress-item-inactive";
            if (completed) {
                targetItemClass = "progress-item-complete";
            } else if (active) {
                targetItemClass = "progress-item-active";
            }

            items.push({
                num: i,
                completed: completed,
                classes: targetItemClass
            });
        }

        this.items = items;
    }
}