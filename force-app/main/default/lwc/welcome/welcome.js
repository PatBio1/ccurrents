import { wire, LightningElement } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import labels from 'c/labelService';

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
        return (this.currentPage === 'Home');
    }

    get showAbout() {
        return (this.currentPage === 'About');
    }

    get showChooseCenter() {
        return (this.currentPage === 'Choose Center');
    }

    get showProfile() {
        return (this.currentPage === 'Profile');
    }

    get showLogin() {
        return (this.currentPage === 'Login');
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
        this.currentPage = 'About';
    }

    onBackButtonClick() {
        this.currentPage = 'Home';
    }

    onNextButtonClick(event) {
        this.center = event.detail.selectedCenter;
        this.currentPage = 'Profile';
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
        this.currentPage = 'Choose Center';
    }

    onLoginButtonClick() {
        this.currentPage = 'Login';
    }

    onSignUpButtonClick() {
        this.currentPage = 'Choose Center';
    }

}