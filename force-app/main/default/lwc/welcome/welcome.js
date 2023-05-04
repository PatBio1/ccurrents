import { wire, LightningElement } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import labels from 'c/labelService';
import termsOfServiceModal from 'c/termsOfServiceModal';

const PAGE_HOME = 'Home';
const PAGE_ABOUT = 'About';
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
        termsOfServiceModal.open().then((confirmed) => {
            if (confirmed) {
                this.currentPage = PAGE_CHOOSE_CENTER;
            }
        });
    }

    onLoginButtonClick() {
        this.currentPage = PAGE_LOGIN;
    }

}