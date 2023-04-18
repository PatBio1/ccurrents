import { wire, LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';
import isGuest from '@salesforce/user/isGuest';
import userId from '@salesforce/user/Id';
import userSmallPhotoUrl from '@salesforce/schema/User.SmallPhotoUrl';
import proesisDonor from '@salesforce/resourceUrl/ProesisDonor';
import logoutModal from 'c/logoutModal';
import labels from 'c/labelService';
import util from 'c/util';

import getDonorRewardsInfo from '@salesforce/apex/DonorSelector.getDonorRewardsInfo';

export default class Menu extends NavigationMixin(LightningElement) {

    isGuest = isGuest;
    isInitialied = false;

    labels = labels;
    showMenu = false;

    menuStyle = 'background: url(' + proesisDonor + '/images/Proesis-Gradient3.png) no-repeat center center fixed; -webkit-background-size: cover; -moz-background-size: cover; -o-background-size: cover; background-size: cover;';

    userLoyaltyLevel;
    photoUrl;

    get displayLoyaltyLevel() {
        return this.userLoyaltyLevel || "Donor (Default)";
    }

    get hasUnreadNotifications() {
        return true;
    }

    async renderedCallback() {
        if (!this.isInitialied && !this.isGuest) {
            this.isInitialied = true;

            let donorRewardsInfo = await getDonorRewardsInfo();
            if (donorRewardsInfo && donorRewardsInfo.currentLoyaltyLevel) {
                this.userLoyaltyLevel = donorRewardsInfo.currentLoyaltyLevel;
            }
        }
    }

    @wire(getRecord, { recordId: userId, fields: [userSmallPhotoUrl]}) 
    userDetails({error, data}) {
        if (data) {
            this.photoUrl = data.fields.SmallPhotoUrl.value;
        }
    }

    onHamburgerClick() {
        this.showMenu = true;
    }

    onCloseClick() {
        this.showMenu = false;
    }

    onLoyaltyTiersButtonClick() {
        util.navigateToPage(this, 'Loyalty_Tiers__c');

        this.showMenu = false;
    }

    onDonorTipsButtonClick() {
        util.navigateToPage(this, 'Donor_Tips__c');

        this.showMenu = false;
    }

    onBuddyRewardsButtonClick() {
        window.open('https://proesisbio.com/', "_blank");
    }

    onSupportButtonClick() {
        util.navigateToPage(this, 'Support__c');

        this.showMenu = false;
    }

    onLogoutButtonClick() {
        logoutModal.open().then(() => {
            this.showMenu = false;
        });
    }

    onNotificationsClick() {
        util.navigateToPage(this, 'Notifications__c');
    }

    onPhotoClick() {
        util.navigateToPage(this, 'Profile__c');
    }

    onPrivacyPolicySelect() {
        window.open(this.labels.privacyPolicyLink);
    }

    onTermsOfServiceSelect() {
        window.open(this.labels.termsOfServiceLink);
    }
}