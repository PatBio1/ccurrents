import { wire, LightningElement } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import formFactor from '@salesforce/client/formFactor';
import labels from 'c/labelService';

const PAGE_HOME = 'Home';
const PAGE_ABOUT = 'About';
const PAGE_TERMS_OF_SERVICE = 'Terms of Service';
const PAGE_CHOOSE_CENTER = 'Choose Center';
const PAGE_PROFILE = 'Profile';
const PAGE_LOGIN = 'Login';

export default class Welcome extends NavigationMixin(LightningElement) {

    labels = labels;
    loading = false;
    currentPage = 'Home';
    language = 'en_US';
    startURL;
    center;

    get showVideo() {
        return (formFactor !== 'Small');
    }

    get copyrightLabel() {
        const currentYear = new Date().getFullYear();
        return labels.formatLabel(labels.copyright, [currentYear]);
    }

    get showHome() {
        return (this.currentPage === PAGE_HOME);
    }

    get showAbout() {
        return (this.currentPage === PAGE_ABOUT);
    }

    get showTermsOfService() {
        return (this.currentPage === PAGE_TERMS_OF_SERVICE);
    }

    get showChooseCenter() {
        return (this.currentPage === PAGE_CHOOSE_CENTER);
    }

    get showProfile() {
        return (this.currentPage === PAGE_PROFILE);
    }

    get showLogin() {
        return (this.currentPage === PAGE_LOGIN);
    }

    get languageOptions() {
        return [
            {label: labels.english, value: 'en_US'},
            {label: labels.spanish, value: 'es_US'}
        ];
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.language = currentPageReference.state?.language;
            this.startURL = currentPageReference.state?.startURL;
        }
    }

    onAboutButtonClick() {
        this.currentPage = PAGE_ABOUT;
    }

    onBackButtonClick() {
        this.currentPage = PAGE_HOME;
    }

    onDonorExists(event) {
        this.currentPage = PAGE_LOGIN;

        // Allow the DOM to render <c-login> before querying for it.
        setTimeout(() => {
            this.template.querySelector('c-login').donorExists(event.detail.email);
        }, 100);
    }

    onNextButtonClick(event) {
        this.center = event.detail.selectedCenter;
        this.currentPage = PAGE_PROFILE;
    }

    onLanguageChange(event) {
        this.language = event.detail.value;

        this.loading = true;

        if (this.startURL) {
            this.startURL += '&language=' + this.language;
        } else {
            this.startURL = '/ProesisDonor/s/?language=' + this.language;
        }

        location.href = '/ProesisDonor/s/login?language=' + this.language + '&startURL=' + encodeURIComponent(this.startURL);
    }

    onJoinUsButtonClick() {
        this.currentPage = PAGE_TERMS_OF_SERVICE;
    }

    onTermsOfServiceCancelButtonClick() {
        this.currentPage = PAGE_HOME;
    }

    onTermsOfServiceConfirmButtonClick() {
        this.currentPage = PAGE_CHOOSE_CENTER;
    }

    onLoginButtonClick() {
        this.currentPage = PAGE_LOGIN;
    }

}