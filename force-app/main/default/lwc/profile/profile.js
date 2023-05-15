import { api, track, wire, LightningElement } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import constants from 'c/constants';
import labels from 'c/labelService';
import util from 'c/util';
import upsertLead from '@salesforce/apex/ProfileController.upsertLead';
import createUser from '@salesforce/apex/ProfileController.createUser';
import createUserFromScheduler from '@salesforce/apex/ProfileController.createUserFromScheduler';
import setupUser from '@salesforce/apex/ProfileController.setupUser';
import setupPhoto from '@salesforce/apex/ProfileController.setupPhoto';
import removePhoto from '@salesforce/apex/ProfileController.removePhoto';
import sendVerificationEmail from '@salesforce/apex/ProfileController.sendVerificationEmail';
import verifyEmailCode from '@salesforce/apex/ProfileController.verifyEmailCode';
import smsVerificationEnabled from '@salesforce/apex/ProfileController.smsVerificationEnabled';
import sendVerificationSms from '@salesforce/apex/ProfileController.sendVerificationSms';
import verifySmsCode from '@salesforce/apex/ProfileController.verifySmsCode';
import login from '@salesforce/apex/LoginController.login';
import fileUploadStyles from '@salesforce/resourceUrl/fileUploadStyles';
import language from '@salesforce/i18n/lang';

const PAGE_BASIC_PROFILE = 'Basic Profile';
const PAGE_ADDRESS = 'Address';
const PAGE_PICTURE = 'Picture';
const PAGE_PASSWORD = 'Password';
const PAGE_VERIFY_EMAIL = 'Verify Email';
const PAGE_VERIFY_PHONE = 'Verify Phone';
const PAGE_CONGRATULATIONS = 'Congratulations';

export default class Profile extends LightningElement {

    @api isSchedulerView = false;

    minPasswordCharacters = constants.minPasswordCharacters;
    maxPasswordCharacters = constants.maxPasswordCharacters;

    labels = labels;
    suffixOptions = constants.suffixOptions;
    stateOptions = constants.stateOptions;
    loading = false;
    currentPage = PAGE_BASIC_PROFILE;
    @track profile = {
        howGetToCenter: '',
        language: language.replace('-', '_'),
        isAcceptingMarketingComms: true
    };
    resendEmailCodeEnabled = true;
    emailVerificationsExhausted = false;
    resendSmsCodeEnabled = true;
    smsVerificationsExhausted = false;
    startURL;

    phoneRegex = new RegExp("^[0-9]{3}-[0-9]{3}-[0-9]{4}$");

    @api center;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.startURL = currentPageReference.state?.startURL;
        }
    }

    get verifyEmailInstructionsLabel() {
        return labels.formatLabel(labels.verifyEmailInstructions, [this.profile.email]);
    }

    get verifyPhoneInstructionsLabel() {
        return labels.formatLabel(labels.verifyPhoneInstructions, [this.profile.mobilePhone]);
    }

    get showBasicProfile() {
        return (this.currentPage === PAGE_BASIC_PROFILE);
    }

    get showAddress() {
        return (this.currentPage === PAGE_ADDRESS);
    }

    get showPicture() {
        return (this.currentPage === PAGE_PICTURE && !this.isSchedulerView);
    }

    get showPassword() {
        return (this.currentPage === PAGE_PASSWORD && !this.isSchedulerView);
    }

    get showVerifyEmail() {
        return (this.currentPage === PAGE_VERIFY_EMAIL && !this.isSchedulerView);
    }

    get showVerifyPhone() {
        return (this.currentPage === PAGE_VERIFY_PHONE && !this.isSchedulerView);
    }

    get showCongratulations() {
        return (this.currentPage === PAGE_CONGRATULATIONS);
    }

    get carSelected() {
        return this.profile.howGetToCenter.split(';').includes('Car');
    }

    get busSelected() {
        return this.profile.howGetToCenter.split(';').includes('Bus');
    }

    get walkSelected() {
        return this.profile.howGetToCenter.split(';').includes('Walk');
    }

    get taxiSelected() {
        return this.profile.howGetToCenter.split(';').includes('Taxi');
    }

    get hasPhoto() {
        return util.isNotBlank(this.profile.photoUrl);
    }

    get basicProfileValid() {
        return (
            util.isNotBlank(this.profile.firstName) &&
            util.isNotBlank(this.profile.lastName) &&
            util.isNotBlank(this.profile.email) &&
            util.isNotBlank(this.profile.mobilePhone) &&
            this.phoneRegex.test(this.profile.mobilePhone)
        );
    }

    get addressValid() {
        return (
            util.isNotBlank(this.profile.street) &&
            (util.isNotBlank(this.profile.city) || util.isNotBlank(this.profile.postalCode))
        );
    }

    get passwordValid() {
        return (
            util.isNotBlank(this.profile.password) &&
            this.profile.password.length >= this.minPasswordCharacters &&
            util.isValidPassword(this.profile.password) &&
            this.profile.password.trim() === this.profile.passwordConfirm?.trim()
        );
    }

    get verifyEmailValid() {
        return (
            util.isNotBlank(this.profile.emailCode) &&
            this.profile.emailCode.trim().length === 6
        );
    }

    get verifySmsValid() {
        return (
            util.isNotBlank(this.profile.smsCode) &&
            this.profile.smsCode.trim().length === 6
        );
    }

    connectedCallback() {
        Promise.all([
            loadStyle(this, fileUploadStyles)
        ]);
    }

    onAcceptMarketingCommsChange(event) {
        this.profile.isAcceptingMarketingComms = event.target.checked;
    }

    onFieldChange(event) {
        let field = event.target?.dataset?.field;

        this.profile[field] = event.detail?.value;
    }

    onMobilePhoneChange(event) {
        this.onFieldChange(event);

        let mobilePhoneInput = this.template.querySelector('lightning-input[data-field="mobilePhone"]');

        let formattedPhone = this.profile.mobilePhone.replace(/[^\d]/g, '');

        if (formattedPhone.length === 3) {
            formattedPhone = formattedPhone + '-';
        } else if (formattedPhone.length > 3 && formattedPhone.length < 7) {
            formattedPhone = formattedPhone.slice(0, 3) + '-' + formattedPhone.slice(3) + (formattedPhone.length === 6 ? '-' : '');
        } else if (formattedPhone.length >= 7) {
            formattedPhone = formattedPhone.slice(0, 3) + '-' + formattedPhone.slice(3, 6) + '-' + formattedPhone.slice(6, 10);
        }

        mobilePhoneInput.value = this.profile.mobilePhone = formattedPhone;

        if (!this.phoneRegex.test(this.profile.mobilePhone)) {
            mobilePhoneInput.setCustomValidity(labels.mobilePhoneRequirements);
        } else {
            mobilePhoneInput.setCustomValidity('');
        }

        mobilePhoneInput.reportValidity();
    }

    onPasswordChange(event) {
        this.onPasswordConfirmChange(event);

        let passwordInput = this.template.querySelector('lightning-input[data-field="password"]');

        if (!util.isValidPassword(this.profile.password)) {
            passwordInput.setCustomValidity(labels.passwordRequirements);
        } else {
            passwordInput.setCustomValidity('');
        }

        passwordInput.reportValidity();
    }

    onPasswordConfirmChange(event) {
        this.onFieldChange(event);

        let passwordConfirmInput = this.template.querySelector('lightning-input[data-field="passwordConfirm"]');

        if (this.profile?.password?.trim() !== this.profile.passwordConfirm?.trim()) {
            passwordConfirmInput.setCustomValidity(labels.passwordsDontMatch);
        } else {
            passwordConfirmInput.setCustomValidity('');
        }

        passwordConfirmInput.reportValidity();
    }

    onHowGetToCenterChange(event) {
        let type = event.target.dataset.type;
        let values = this.profile.howGetToCenter.split(';').filter(value => value !== type);

        if (event.target.checked) {
            values.push(type);
        }

        this.profile.howGetToCenter = values.join(';');
    }

    onBackButtonClick() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    onBasicProfileNextButtonClick() {
        this.saveProfile(PAGE_ADDRESS);
    }

    onAddressPreviousButtonClick() {
        this.saveProfile(PAGE_BASIC_PROFILE);
    }

    onAddressNextButtonClick() {
        if (this.isSchedulerView) {
            // Toggles the loading screen on the scheduler view
            this.dispatchEvent(new CustomEvent('begindonorcreate'));

            this.profile.centerId = this.center.id;
            createUserFromScheduler({ profile: this.profile }).then(response => {
                console.log('createUserFromScheduler response', response);

                this.dispatchEvent(new CustomEvent('schedulerdonorcreate', {
                    detail: {
                        donorId: response
                    }
                }));
            }).catch((error) => {
                util.showToast(this, 'error', 'Create Donor Error', error);

                this.loading = false;
            });

            return;
        }

        this.saveProfile(PAGE_PICTURE);
    }

    onPhotoUploaded(event) {
        this.loading = true;

        this.profile.photoContentVersionId = event.detail.files[0].contentVersionId;

        const request = {
            profile: this.profile
        };

        console.log('setupPhoto request', JSON.stringify(request));

        setupPhoto(request).then(response => {
            console.log('setupPhoto response', response);
            this.profile.photoUrl = response.replaceAll('"', '');
        }).catch((error) => {
            util.showGuestToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    onRemovePhotoButtonClick() {
        this.loading = true;

        const request = {
            contentVersionId: this.profile.photoContentVersionId
        };

        console.log('removePhoto request', JSON.stringify(request));

        removePhoto(request).then(() => {
            this.profile.photoContentVersionId = undefined;
            this.profile.photoUrl = undefined;
        }).catch((error) => {
            util.showGuestToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    onPicturePreviousButtonClick() {
        this.saveProfile(PAGE_ADDRESS);
    }

    onPictureNextButtonClick() {
        this.saveProfile(PAGE_PASSWORD);
    }

    onPasswordPreviousButtonClick() {
        this.currentPage = PAGE_PICTURE;
    }

    onPasswordNextButtonClick() {
        this.loading = true;

        const request = {
            profile: this.profile
        };

        console.log('sendVerificationEmail request', JSON.stringify(request));

        sendVerificationEmail(request).then(response => {
            console.log('sendVerificationEmail response', response);

            this.currentPage = PAGE_VERIFY_EMAIL;
        }).catch((error) => {
            util.showGuestToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    onResendEmailCodeButtonClick() {
        this.loading = true;

        const request = {
            profile: this.profile
        };

        console.log('sendVerificationEmail request', JSON.stringify(request));

        sendVerificationEmail(request).then(response => {
            console.log('sendVerificationEmail response', response);
            if (response !== true) {
                this.resendEmailCodeEnabled = false;
            }
        }).catch((error) => {
            util.showGuestToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });

        this.profile.emailCode = '';
    }

    onVerifyEmailSkipButtonClick() {
        this.verifySMS();
    }

    onVerifyEmailButtonClick() {
        this.loading = true;

        const request = {
            profile: this.profile
        };

        console.log('verifyEmailCode request', JSON.stringify(request));

        verifyEmailCode(request).then(response => {
            console.log('verifyEmailCode response', response);
            const result = response.replaceAll('"', '');

            if (result === 'Success') {
                this.verifySMS();
            } else if (result === 'Incorrect') {
                this.loading = false;

                util.showGuestToast(this, 'error', labels.incorrectCode, labels.incorrectCodeMessage);
            } else {
                this.emailVerificationsExhausted = true;
                this.loading = false;
            }
        }).catch((error) => {
            this.loading = false;

            util.showGuestToast(this, 'error', labels.error, error);
        });
    }

    verifySMS() {
        this.loading = true;

        smsVerificationEnabled().then(response => {
            console.log('smsVerificationEnabled response', response);

            if (response === true) {
                const request = {
                    profile: this.profile
                };

                console.log('sendVerificationSms request', request);

                sendVerificationSms(request).then(response => {
                    console.log('sendVerificationSms response', response);
                    this.currentPage = PAGE_VERIFY_PHONE;
                }).catch((error) => {
                    util.showGuestToast(this, 'error', labels.error, error);
                }).finally(() => {
                    this.loading = false;
                });
            } else {
                this.phoneVerified();
            }
        }).catch((error) => {
            util.showGuestToast(this, 'error', labels.error, error);
            this.loading = false;
        });
    }

    onResendSmsCodeButtonClick() {
        this.loading = true;

        const request = {
            profile: this.profile
        };

        console.log('sendVerificationSms request', JSON.stringify(request));

        sendVerificationSms(request).then(response => {
            console.log('sendVerificationSms response', response);
            if (response !== true) {
                console.log('out of attempts');
            }
        }).catch((error) => {
            util.showGuestToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });

        this.profile.smsCode = '';
    }

    onVerifyPhoneSkipButtonClick() {
        this.phoneVerified();
    }

    onVerifyPhoneButtonClick() {
        this.loading = true;

        const request = {
            profile: this.profile
        };

        console.log('verifySmsCode request', JSON.stringify(request));

        verifySmsCode(request).then(response => {
            console.log('verifySmsCode response', response);
            const result = response.replaceAll('"', '');

            if (result === 'Success') {
                this.phoneVerified();
            } else if (result === 'Incorrect') {
                this.loading = false;

                util.showGuestToast(this, 'error', labels.incorrectCode, labels.incorrectCodeMessage);
            } else {
                this.smsVerificationsExhausted = true;
                this.loading = false;
            }
        }).catch((error) => {
            this.loading = false;

            util.showGuestToast(this, 'error', labels.error, error);
        });
    }

    phoneVerified() {
        this.loading = true;

        this.profile.centerId = this.center.id;

        const request = {
            profile: this.profile
        };

        console.log('createUser request', JSON.stringify(request));

        createUser(request).then(response => {
            console.log('createUser response', response);

            this.profile.userId = response;

            this.assignPermissions();
        }).catch((error) => {
            this.loading = false;

            util.showGuestToast(this, 'error', labels.error, error);
        });
    }

    onScheduleButtonClick() {
        this.loading = true;

        const request = {
            username: this.profile.email,
            password: this.profile.password,
            startUrl: this.startURL
        };

        console.log('login request', JSON.stringify(request));

        login(request).then(response => {
            window.location.href = response;
        }).catch((error) => {
            util.showGuestToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    assignPermissions() {
        const request = {
            profile: this.profile
        };

        console.log('setupUser request', JSON.stringify(request));

        setupUser(request).then(response => {
            this.currentPage = PAGE_CONGRATULATIONS;
        }).catch((error) => {
            util.showGuestToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    saveProfile(nextPage) {
        this.loading = true;

        const request = {
            profile: this.profile
        };

        console.log('upsertLead request', JSON.stringify(request));

        upsertLead(request).then(response => {
            console.log('upsertLead response', response);

            this.profile.id = response;

            this.currentPage = nextPage;
        }).catch((error) => {
            util.showGuestToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

}