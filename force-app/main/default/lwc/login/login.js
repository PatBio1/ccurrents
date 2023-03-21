import { LightningElement } from 'lwc';
import login from '@salesforce/apex/LoginController.login';
import sendVerificationEmail from '@salesforce/apex/LoginController.sendVerificationEmail';
import util from 'c/util';
import labels from 'c/labelService';

const PAGE_LOGIN = 'Login';
const PAGE_FORGOT_PASSWORD = 'Forgot Password';
const PAGE_VERIFY_EMAIL = 'Verify Email';
const PAGE_SET_PASSWORD = 'Set Password';

export default class Menu extends LightningElement {

    minPasswordCharacters = 8;
    maxPasswordCharacters = 16;

    labels = labels;
    loading = false;
    currentPage = PAGE_LOGIN;
    username;
    password;
    email;
    emailCode;

    get showLogin() {
        return (this.currentPage === PAGE_LOGIN);
    }

    get showForgotPassword() {
        return (this.currentPage === PAGE_FORGOT_PASSWORD);
    }

    get showVerifyEmail() {
        return (this.currentPage === PAGE_VERIFY_EMAIL);
    }

    get showSetPassword() {
        return (this.currentPage === PAGE_SET_PASSWORD);
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

    get emailCodeValid() {
        return (
            util.isNotBlank(this.emailCode) &&
            this.emailCode.trim().length === 6
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

    onEmailCodeChange(event) {
        this.emailCode = event.detail?.value;
    }

    onForgotButtonClick() {
        this.currentPage = PAGE_FORGOT_PASSWORD;
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
        this.currentPage = PAGE_LOGIN;
    }

    onSendButtonClick() {
        this.loading = true;

        const request = {
            username: this.email
        };

        console.log('sendVerificationEmail request', JSON.stringify(request));

        sendVerificationEmail(request).then(response => {
            console.log('sendVerificationEmail response', response);
        }).catch((error) => {
            console.log(error);
        }).finally(() => {
this.currentPage = PAGE_VERIFY_EMAIL;
            this.loading = false;
        });
    }

    onVerifyEmailButtonClick() {
        this.currentPage = PAGE_SET_PASSWORD;
    }

    onSetPasswordButtonClick() {
        this.currentPage = PAGE_LOGIN;
    }

}