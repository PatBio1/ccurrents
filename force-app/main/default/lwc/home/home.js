import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import labels from 'c/labelService';
import util from 'c/util';
import hasFutureVisit from '@salesforce/apex/SchedulerController.hasFutureVisit';
import getDonorRewardsInfo from '@salesforce/apex/DonorSelector.getDonorRewardsInfo';
import language from '@salesforce/i18n/lang';
import locale from '@salesforce/i18n/locale';

export default class Home extends NavigationMixin(LightningElement) {

    labels = labels;
    hasRendered = false;
    loading = true;
    donorRewardsInfo;

    renderedCallback() {
        if (this.hasRendered) {
            return;
        }

        this.hasRendered = true;

        // If current language doesn't match the user's locale,
        // reload the page with the language from the locale.
        if (language !== locale) {
            const url = location.href + '?language=' + (locale.indexOf('es') === -1 ? 'en_US' : 'es_US');
            location.href = url;

            this.loading = false;
        } else {
            hasFutureVisit().then(response => {
                if (!response) {
                    util.navigateToPage(this, 'Schedule__c');
                }
            }).catch((error) => {
                util.showToast(this, 'error', labels.error, error);
            }).finally(() => {
                this.loading = false;
            });
        }

        // Load Donor Rewards info
        getDonorRewardsInfo().then(response => {
            this.donorRewardsInfo = response;
        }).catch((error) => {
            util.showToast(this, 'error', labels.error, error);
        });
    }

}