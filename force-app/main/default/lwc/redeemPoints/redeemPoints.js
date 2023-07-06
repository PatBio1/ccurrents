import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import redeemPoints from '@salesforce/apex/RedeemPointsController.redeemPoints';
import labels from 'c/labelService';

export default class RedeemPoints extends LightningElement {
    @api donorRewardsInfo;

    amountOfPointsToRedeem = 0;
    labels = labels;
    isLoading = false;

    get minimumWithdrawalAmount() {
        if (!this.donorRewardsInfo || !this.donorRewardsInfo.minimumWithdrawalAmount) {
            return 0;
        }

        return this.donorRewardsInfo.minimumWithdrawalAmount;
    }

    get donorBalance() {
        if (!this.donorRewardsInfo || !this.donorRewardsInfo.donorPoints) {
            return 0;
        }

        return this.donorRewardsInfo.donorPoints;
    }

    get conversationRate() {
        if (!this.donorRewardsInfo || !this.donorRewardsInfo.pointsToDollarsConversionRate) {
            return 0;
        }

        let multiplier = (this.donorRewardsInfo.dollarIncrementAmount) ? this.donorRewardsInfo.dollarIncrementAmount : 1;
        return this.donorRewardsInfo.pointsToDollarsConversionRate * multiplier;
    }

    get maxAmountOfPointsToRedeem() {
        let balance = this.donorBalance;
        let conversationRate = this.conversationRate;

        return Math.floor(balance / conversationRate) * conversationRate;
    }

    get currentDollarsAfterRedeem() {
        let amountOfPointsToRedeem = this.amountOfPointsToRedeem;
        if (!amountOfPointsToRedeem) {
            return 0;
        }

        let conversationRate = this.donorRewardsInfo.pointsToDollarsConversionRate;
        return Math.floor(amountOfPointsToRedeem / conversationRate);
    }

    get underflowMessage() {
        return `You must redeem at least ${this.minimumWithdrawalAmount} ${labels.pointBrandName}`;
    }

    get overflowMessage() {
        return `You can't redeem more than ${this.maxAmountOfPointsToRedeem} ${labels.pointBrandName}`;
    }

    get stepMismatchMessage() {
        return `You must redeem in increments of ${this.conversationRate} ${labels.pointBrandName}`;
    }

    get cantRedeemPoints() {
        let requiredFields = this.template.querySelectorAll('lightning-input');
        let cantRedeemPoints = false;

        for(let requiredFieldElement of requiredFields) {
            if (!requiredFieldElement.checkValidity()) {
                cantRedeemPoints = true;
                break;
            }
        }

        if (!this.amountOfPointsToRedeem) {
            cantRedeemPoints = true;
        }

        return cantRedeemPoints;
    }

    handleChangeAmountOfPointsToRedeem(event) {
        this.amountOfPointsToRedeem = event.target.value;
    }

    handlePopulateMaxPoints(event) {
        this.amountOfPointsToRedeem = this.maxAmountOfPointsToRedeem;
    }

    handleExitRedeemPointsScreen(event) {
        this.dispatchEvent(new CustomEvent('exitscreen'));
    }

    async handleRedeemPoints(event) {
        this.isLoading = true;

        try {
            await redeemPoints({ donorId: this.donorRewardsInfo.donorId, pointsToRedeem: this.amountOfPointsToRedeem });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Redeem Points In Progress!',
                message: 'The request to redeem your points has been submitted, check the payment history screen for updates.',
                variant: 'success'
            }));

            this.dispatchEvent(new CustomEvent('exitscreen'));
        } catch(e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Redeem Points Error',
                message: e.body.message,
                variant: 'error'
            }));

            console.error(e);
        } finally {
            this.isLoading = false;
        }
    }
}