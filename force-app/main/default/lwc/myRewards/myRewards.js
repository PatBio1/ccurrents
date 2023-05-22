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

const REWARDS_SCREEN_KEY = 'rewardsScreen';
const REDEEM_POINTS_SCREEN_KEY = 'redeemPoints';

export default class MyRewards extends NavigationMixin(LightningElement) {

    userCurrency = userCurrency;
    userTimezone = userTimezone;
    labels = labels;

    donorRewardsInfo;
    loyaltyLevelsInfo;
    @track paymentHistory;
    isLoading = false;

    get hasRewardsVideo() {
        return (this.labels.rewardsVideoLink && this.labels.rewardsVideoLink.toLowerCase() !== 'null')
    }

    get isRewardScreen() {
        return (this.currentScreen === REWARDS_SCREEN_KEY);
    }

    get isRedeemPointsScreen() {
        return (this.currentScreen === REDEEM_POINTS_SCREEN_KEY);
    }

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

    onLostCardButtonClick() {
        LostMyCardModal.open();
    }

    onWatchVideoButtonClick() {
        RewardsVideoModal.open();
    }

    navigateToLoyaltyTiers(event) {
        util.navigateToPage(this, 'Loyalty_Tiers__c');
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
        util.navigateToPage(this, 'Schedule__c');
    }

    togglePaymentDetails(event) {
        let transactionId = event.currentTarget.dataset.transactionId;
        let transaction = this.paymentHistory.find(transaction => transaction.transactionId === transactionId);

        if (transaction) {
            transaction.displayDetails = !transaction.displayDetails;
            transaction.displayIcon = transaction.displayDetails ? "utility:down" : "utility:right";
        }
    }

    navigateToRedeemPoints(event) {
        this.currentScreen = REDEEM_POINTS_SCREEN_KEY;
    }

    handleExitRedeemPointsScreen(event) {
        this.currentScreen = REWARDS_SCREEN_KEY;
    }
}