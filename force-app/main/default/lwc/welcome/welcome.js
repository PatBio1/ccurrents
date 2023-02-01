import { wire, LightningElement } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import labels from 'c/labelService';

export default class Welcome extends NavigationMixin(LightningElement) {

    labels = labels;
    currentPage = 'Home';
    language = 'en_US';
    center;

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

        location.href = '/ProesisDonor/s/?language=' + this.language;
    }

    onJoinUsButtonClick() {
        this.currentPage = 'Choose Center';
    }

    onLoginButtonClick() {
        this[NavigationMixin.Navigate]({
            type: 'comm__loginPage',
            attributes: {
                actionName: 'login'
            }
        });
    }

}