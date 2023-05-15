import { wire, LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';
import isGuest from '@salesforce/user/isGuest';
import userId from '@salesforce/user/Id';
import userContactId from '@salesforce/schema/User.ContactId';
import userSmallPhotoUrl from '@salesforce/schema/User.SmallPhotoUrl';
import proesisDonor from '@salesforce/resourceUrl/ProesisDonor';
import logoutModal from 'c/logoutModal';
import labels from 'c/labelService';
import util from 'c/util';

import hasUnreadNotifications from '@salesforce/apex/NotificationsController.hasUnreadNotifications';
import getDonorRewardsInfo from '@salesforce/apex/DonorSelector.getDonorRewardsInfo';

export default class Menu extends NavigationMixin(LightningElement) {

    isGuest = isGuest;
    isMobileApp = (navigator?.userAgent?.toLowerCase().indexOf('salesforce') !== -1);
    isInitialied = false;

    labels = labels;
    showMenu = false;

    menuStyle = 'background: url(' + proesisDonor + '/images/Proesis-Gradient3.png) no-repeat center center fixed; -webkit-background-size: cover; -moz-background-size: cover; -o-background-size: cover; background-size: cover;';

    userLoyaltyLevel;
    doesUserHaveUnreadNotifications = false;
    contactId;
    photoUrl;

    get linkClass() {
        return (this.isMobileApp ? 'slds-m-bottom_large' : 'slds-m-bottom_small') + ' slds-text-align_center';
    }

    async renderedCallback() {
        if (!this.isInitialied && !this.isGuest) {
            this.isInitialied = true;

            let [doesHaveUnreadNotifications, donorRewardsInfo] = await Promise.all([hasUnreadNotifications(), getDonorRewardsInfo()]);

            this.doesUserHaveUnreadNotifications = doesHaveUnreadNotifications;
            if (donorRewardsInfo && donorRewardsInfo.currentLoyaltyLevel) {
                console.log(donorRewardsInfo);
                this.userLoyaltyLevel = donorRewardsInfo.currentLoyaltyLevel;
            }
        }
    }

    @wire(getRecord, { recordId: userId, fields: [userContactId, userSmallPhotoUrl]}) 
    userDetails({error, data}) {
        if (data) {
            this.contactId = data.fields.ContactId.value;
            this.photoUrl = data.fields.SmallPhotoUrl.value;
        }
    }

    onHamburgerClick() {
        this.showMenu = true;
    }

    onCloseClick() {
        this.showMenu = false;
    }

    onHomeButtonClick() {
        util.navigateToPage(this, 'Home');

        this.showMenu = false;
    }

    onMyAppointmentsButtonClick() {
        util.navigateToPage(this, 'Appointments__c');

        this.showMenu = false;
    }

    onScheduleButtonClick() {
        util.navigateToPage(this, 'Schedule__c');

        this.showMenu = false;
    }

    onMyRewardsButtonClick() {
        util.navigateToPage(this, 'Rewards__c');

        this.showMenu = false;
    }

    onCentersButtonClick() {
        util.navigateToPage(this, 'Centers__c');

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
        const url = 'https://cloud.m.proesisbio.com/buddy-referral?referrer=' + this.contactId;
        window.open(url, '_self');
    }

    onSupportButtonClick() {
        util.navigateToPage(this, 'Support__c');

        this.showMenu = false;
    }

    onLegalTermsButtonClick() {
        window.open(this.labels.legalTermsLink, '_self');

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

}