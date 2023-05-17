import { api, wire, LightningElement } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import login from '@salesforce/apex/LoginController.login';
import sendVerificationEmail from '@salesforce/apex/LoginController.sendVerificationEmail';
import verifyEmailCode from '@salesforce/apex/LoginController.verifyEmailCode';
import setPassword from '@salesforce/apex/LoginController.setPassword';
import constants from 'c/constants';
import labels from 'c/labelService';
import util from 'c/util';

const PAGE_LOGIN = 'Login';
const PAGE_FORGOT_PASSWORD = 'Forgot Password';
const PAGE_VERIFY_EMAIL = 'Verify Email';
const PAGE_SET_PASSWORD = 'Set Password';

export default class Menu extends LightningElement {

    minPasswordCharacters = constants.minPasswordCharacters;
    maxPasswordCharacters = constants.maxPasswordCharacters;

    labels = labels;
    loading = false;
    currentPage = PAGE_LOGIN;
    username;
    email;
    emailCode;
    emailVerificationsExhausted = false;
    password;
    passwordConfirm;
    startURL;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.startURL = currentPageReference.state?.startURL;
        }
    }

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

    get passwordValid() {
        return (
            util.isNotBlank(this.password) &&
            this.password.length >= this.minPasswordCharacters &&
            util.isValidPassword(this.password) &&
            this.password.trim() === this.passwordConfirm?.trim()
        );
    }

    @api donorExists(email) {
        this.email = email;

        this.currentPage = PAGE_VERIFY_EMAIL;

        this.onSendButtonClick();
    }

    onUsernameChange(event) {
        this.username = event.detail?.value;
    }

    onPasswordChange(event) {
        this.password = event.detail?.value;

        this.onPasswordConfirmChange(event);

        let passwordInput = this.template.querySelector('lightning-input[data-field="password"]');

        if (!util.isValidPassword(this.password)) {
            passwordInput.setCustomValidity(labels.passwordRequirements);
        } else {
            passwordInput.setCustomValidity('');
        }

        passwordInput.reportValidity();
    }

    onPasswordConfirmChange(event) {
        this.passwordConfirm = event.detail?.value;

        let passwordConfirmInput = this.template.querySelector('lightning-input[data-field="passwordConfirm"]');

        if (this.password?.trim() !== this.passwordConfirm?.trim()) {
            passwordConfirmInput.setCustomValidity(labels.passwordsDontMatch);
        } else {
            passwordConfirmInput.setCustomValidity('');
        }

        passwordConfirmInput.reportValidity();
    }

    onEmailChange(event) {
        this.email = event.detail?.value;
    }

    onEmailCodeChange(event) {
        this.emailCode = event.detail?.value;
    }

    onForgotButtonClick() {
        this.password = undefined;
        this.currentPage = PAGE_FORGOT_PASSWORD;
    }

    onLoginButtonClick() {
        this.loading = true;

        const request = {
            username: this.username,
            password: this.password,
            startUrl: this.startURL
        };

        console.log('login request', JSON.stringify(request));

        login(request).then(loginResponse => {
            window.location.href = loginResponse;
        }).catch((error) => {
            this.showToast('error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    onSignUpButtonClick() {
        this.dispatchEvent(new CustomEvent('signup'));
    }

    onBackButtonClick() {
        this.email = undefined;
        this.emailCode = undefined;
        this.password = undefined;
        this.passwordConfirm = undefined;

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

            this.emailVerificationsExhausted = false;
            this.currentPage = PAGE_VERIFY_EMAIL;
        }).catch((error) => {
            this.showToast('error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    onVerifyEmailButtonClick() {
        this.loading = true;

        const request = {
            username: this.email,
            code: this.emailCode
        };

        console.log('verifyEmailCode request', JSON.stringify(request));

        verifyEmailCode(request).then(response => {
            console.log('verifyEmailCode response', response);
            const result = response.replaceAll('"', '');

            if (result === 'Success') {
                this.currentPage = PAGE_SET_PASSWORD;
            } else if (result === 'Incorrect') {
                this.showToast('error', labels.incorrectCode, labels.incorrectCodeMessage);
            } else {
                this.emailVerificationsExhausted = true;
            }
        }).catch((error) => {
            this.showToast('error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    onSetPasswordButtonClick() {
        this.loading = true;

        const request = {
            username: this.email,
            password: this.password
        };

        console.log('setPassword request', JSON.stringify(request));

        setPassword(request).then(response => {
            console.log('setPassword response', response);

            this.password = undefined;
            this.passwordConfirm = undefined;

            this.showToast('success', labels.success, labels.passwordChanged);

            this.currentPage = PAGE_LOGIN;
        }).catch((error) => {
            this.showToast('error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    showToast(variant, title, message, mode) {
        this.refs.loginGuestToast.show(variant, title, util.getFilteredErrorMessage(message), mode);
    }

}