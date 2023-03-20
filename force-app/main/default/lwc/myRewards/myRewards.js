import { LightningElement } from 'lwc';
import labels from 'c/labelService';

export default class MyRewards extends LightningElement {

    labels = labels;

    noGoalSet = true;
    settingGoal = false;
    goalSet = false;
    goalAmount;

    get goalValid() {
        return (this.goalAmount != undefined);
    }

    onSetGoalButtonClick() {
        this.noGoalSet = false;
        this.settingGoal = true;
    }

    onGoalAmountChange(event) {
console.log('onGoalAmountChange', event.data.value);
        this.goalAmount = event.data.value;
console.log('onGoalAmountChange', this.goalAmount);
    }

    onSetGoalCancelButtonClick() {
        this.noGoalSet = true;
        this.settingGoal = false;
    }

    onSetGoalApplyButtonClick() {
        this.settingGoal = false;
        this.goalSet = true;
    }

    onSetNewGoalButtonClick() {
        this.settingGoal = true;
        this.goalSet = false;
    }

    onLostCardButtonClick() {

    }

    onWatchVideoButtonClick() {

    }

}