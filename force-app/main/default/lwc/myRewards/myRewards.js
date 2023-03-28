import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import labels from 'c/labelService';

import userCurrency from '@salesforce/i18n/currency';
import getDonorRewardsInfo from '@salesforce/apex/DonorSelector.getDonorRewardsInfo';
import getLoyaltyLevelDisplayInfo from '@salesforce/apex/LoyaltyLevelService.getLoyaltyLevelDisplayInfo';

const LOYALTY_TIER_NAME_TO_DISPLAY_PROPS = new Map([
    ['Donor (Default)', { displayName: 'Default', style: 'background: rgba(43, 130, 51, 0.2);'}],
    ['Normal Donor +15', { displayName: 'Normal', style: 'background: rgba(152, 50, 133, 0.2);'}],
    ['Signature', { displayName: 'Signature', style: 'background: rgba(212, 195, 179, 0.6);'}],
    ['VIP', { displayName: 'VIP', style: 'background: #E3E3F1;'}],
    ['Royal', { displayName: 'Royal', style: 'background: rgba(219, 202, 160, 0.57);'}]
]);

export default class MyRewards extends NavigationMixin(LightningElement) {

    userCurrency = userCurrency
    labels = labels;

    noGoalSet = true;
    settingGoal = false;
    goalSet = false;
    goalAmount;

    donorRewardsInfo;
    loyaltyLevelsInfo;
    isInitialized = false;
    isLoading = false;

    get cantRedeemPoints() {
        return (this.donorRewardsInfo == undefined || this.donorRewardsInfo.donorPoints < this.donorRewardsInfo.minimumWithdrawalAmount);
    }

    get goalValid() {
        return (this.goalAmount != undefined);
    }

    get hasRewardsInfo() {
        return (!!this.donorRewardsInfo);
    }

    renderedCallback() {
        if (!this.isInitialized) {
            this.initMyRewards();
        }
    }

    async initMyRewards() {
        this.isLoading = true;

        try {
            [this.donorRewardsInfo, this.loyaltyLevelsInfo] = await Promise.all([getDonorRewardsInfo(), getLoyaltyLevelDisplayInfo()]);

            this.loyaltyLevelsInfo.forEach(loyaltyLevel => {
                const displayProps = LOYALTY_TIER_NAME_TO_DISPLAY_PROPS.get(loyaltyLevel.levelName);

                loyaltyLevel.isCurrentTier = (loyaltyLevel.levelName === this.donorRewardsInfo.currentLoyaltyLevel);
                loyaltyLevel.displayName = displayProps.displayName;
                loyaltyLevel.style = displayProps.style;
            });
        } catch(e) {
            console.error(e);
        }
        
        console.log(this.donorRewardsInfo, this.loyaltyLevelsInfo);

        this.isLoading = false;
        this.isInitialized = true;
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

    navigateToLoyaltyTiers(event) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'loyalty-tiers'
            }
        });
    }
}