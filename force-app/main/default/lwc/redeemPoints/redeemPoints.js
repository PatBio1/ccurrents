import { LightningElement, api } from 'lwc';

import labels from 'c/labelService';

export default class RedeemPoints extends LightningElement {
    @api donorRewardsInfo;

    amountOfPointsToRedeem = 0;
    labels = labels;

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

        return this.donorRewardsInfo.pointsToDollarsConversionRate;
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

        let conversationRate = this.conversationRate;
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

    handleChangeAmountOfPointsToRedeem(event) {
        this.amountOfPointsToRedeem = event.target.value;
    }

    handleExitRedeemPointsScreen(event) {
        this.dispatchEvent(new CustomEvent('exitscreen'));
    }
}