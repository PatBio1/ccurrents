import { api, track, LightningElement } from 'lwc';

export default class ProgressIndicator extends LightningElement {

    @api steps;
    @api currentStep;

    @track items = [];

    connectedCallback() {
        console.log('connectedCallback steps', this.steps);
        console.log('connectedCallback currentStep', this.currentStep);

        let items = [];

        for (let i = 1; i <= this.steps; i++) {
            const completed = (i < this.currentStep);
            const active = (i == this.currentStep);

            items.push({
                num: i,
                completed: completed,
                classes: 'slds-progress__item' + (completed ? ' slds-is-completed' : (active ? ' slds-is-active' : '')),
                buttonClasses: 'slds-button slds-progress__marker' + (completed ? ' slds-button_icon slds-progress__marker_icon' :  ''),
                title: 'Step ' + i + (completed ? ' - Completed' : (active ? ' - Active' : ''))
            });
        }

        this.items = items;
    }

}