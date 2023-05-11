import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import LostMyCardModal from 'c/lostMyCardModal';
import RewardsVideoModal from 'c/rewardsVideoModal';

import labels from 'c/labelService';
import util from 'c/util';

import PAYMENT_METHOD_LOGOS from '@salesforce/resourceUrl/Payment_Method_Logos';

import userCurrency from '@salesforce/i18n/currency';
import userTimezone from '@salesforce/i18n/timezone';
import getDonorRewardsInfo from '@salesforce/apex/DonorSelector.getDonorRewardsInfo';
import getLoyaltyLevelDisplayInfo from '@salesforce/apex/LoyaltyLevelService.getLoyaltyLevelDisplayInfo';
import getUserTransactions from '@salesforce/apex/TransactionSelector.getUserTransactions';
import getProfile from '@salesforce/apex/ProfileController.getProfile';

const LOYALTY_TIER_NAME_TO_DISPLAY_PROPS = new Map([
    ["Normal Donor", { displayName: 'Normal', style: 'background: rgba(152, 50, 133, 0.2);'}],
    ['Signature', { displayName: 'Signature', style: 'background: rgba(212, 195, 179, 0.6);'}],
    ['VIP', { displayName: 'VIP', style: 'background: #E3E3F1;'}],
    ['Royal', { displayName: 'Royal', style: 'background: rgba(219, 202, 160, 0.57);'}]
]);

export default class MyRewards extends NavigationMixin(LightningElement) {

    userCurrency = userCurrency;
    userTimezone = userTimezone;
    labels = labels;

    noGoalSet = true;
    settingGoal = false;
    goalSet = false;
    goalAmount;

    donorRewardsInfo;
    loyaltyLevelsInfo;
    @track paymentHistory;
    isLoading = false;

    get userHasCard() {
        return (this.donorRewardsInfo && this.donorRewardsInfo.cardNumber4Digits && this.donorRewardsInfo.cardNumberExpiration);
    }

    get visaLogo() {
        return PAYMENT_METHOD_LOGOS + '/VISA-Logo.svg#visa-logo';
    }

    get cantRedeemPoints() {
        return (
            this.donorRewardsInfo == undefined || 
            !this.donorRewardsInfo.minimumWithdrawalAmount || 
            this.donorRewardsInfo.donorPoints < this.donorRewardsInfo.minimumWithdrawalAmount
        );
    }

    get goalValid() {
        return (this.goalAmount != undefined);
    }

    get hasRewardsInfo() {
        return (!!this.donorRewardsInfo);
    }

    async initMyBalanceTab(event) {
        this.initMyRewards();
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
    }

    async initPaymentHistoryTab(event) {
        this.initPaymentHistoryTab();
    }

    async initPaymentHistoryTab() {
        this.isLoading = true;

        try {
            this.paymentHistory = await getUserTransactions();
            for(let transaction of this.paymentHistory) {
                transaction.displayDetails = false;
                transaction.displayIcon = "utility:right";
            }
        } catch(e) {
            console.error(e);
        }

        console.log(this.paymentHistory);
        this.isLoading = false;
    }

    onSetGoalButtonClick() {
        this.noGoalSet = false;
        this.settingGoal = true;
    }

    onGoalAmountChange(event) {
        this.goalAmount = event.data.value;
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
        LostMyCardModal.open();
    }

    onWatchVideoButtonClick() {
        RewardsVideoModal.open();
    }

    navigateToLoyaltyTiers(event) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'loyalty-tiers'
            }
        });
    }

    onAtmLocatorLinkClick(event) {
        event.preventDefault();

        this.loading = true;

        getProfile().then(response => {
            console.log('getProfile response', response);

            let url = 'http://citiprepaid.geoserve.com/scripts/esrimap.dll?Name=L&Com=adr&Db=DLRCiti1&Ds=&RT=lo&LIM=200&UIn1=380&Dsource=380&Filt=User8%3D4';
            if (response.postalCode) {
                url += '&Zp=' + response.postalCode;
            }

            window.open(url, '_self');
        }).catch((error) => {
            util.showToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    navigateToScheduleAppointment(event) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'schedule'
            }
        });
    }

    togglePaymentDetails(event) {
        let transactionId = event.currentTarget.dataset.transactionId;
        let transaction = this.paymentHistory.find(transaction => transaction.transactionId === transactionId);

        if (transaction) {
            transaction.displayDetails = !transaction.displayDetails;
            transaction.displayIcon = transaction.displayDetails ? "utility:down" : "utility:right";
        }
    }

}