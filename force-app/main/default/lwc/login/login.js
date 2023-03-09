import { LightningElement } from 'lwc';
import login from '@salesforce/apex/LoginController.login';
import util from 'c/util';
import labels from 'c/labelService';

export default class Menu extends LightningElement {

    labels = labels;
    loading = false;
    currentPage = 'Login';
    username;
    password;
    email;

    get showLogin() {
        return (this.currentPage === 'Login');
    }

    get showForgotPassword() {
        return (this.currentPage === 'Forgot Password');
    }

    get loginValid() {
        return (
            util.isNotBlank(this.username) &&
            util.isNotBlank(this.password)
        );
    }

    get forgotValid() {
        return (
            util.isNotBlank(this.email)
        );
    }

    onUsernameChange(event) {
        this.username = event.detail?.value;
    }

    onPasswordChange(event) {
        this.password = event.detail?.value;
    }

    onEmailChange(event) {
        this.email = event.detail?.value;
    }

    onForgotButtonClick() {
        this.currentPage = 'Forgot Password';
    }

    onLoginButtonClick() {
        this.loading = true;

        const request = {
            username: this.username,
            password: this.password,
            startUrl: '/'
        };

        console.log('login request', JSON.stringify(request));

        login(request).then(response => {
            console.log('login response', response);
            window.location.href = response;
            //window.location.href = '/ProesisDonor/s/';
        }).catch((error) => {
            console.log(error);
        }).finally(() => {
            this.loading = false;
        });
    }

    onSignUpButtonClick() {
        this.dispatchEvent(new CustomEvent('signup'));
    }

    onBackButtonClick() {
        this.currentPage = 'Login';
    }

    onSendButtonClick() {

    }

}