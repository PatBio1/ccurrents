import { api, track, LightningElement } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import labels from 'c/labelService';
import util from 'c/util';
import upsertLead from '@salesforce/apex/ProfileController.upsertLead';
import createUser from '@salesforce/apex/ProfileController.createUser';
import setupUser from '@salesforce/apex/ProfileController.setupUser';
import setupPhoto from '@salesforce/apex/ProfileController.setupPhoto';
import removePhoto from '@salesforce/apex/ProfileController.removePhoto';
import sendVerificationEmail from '@salesforce/apex/ProfileController.sendVerificationEmail';
import verifyEmailCode from '@salesforce/apex/ProfileController.verifyEmailCode';
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

    minPasswordCharacters = 8;
    maxPasswordCharacters = 16;

    // At least 1 lowercase, 1 uppercase, 1 number and 1 special character.
    passwordRegex = new RegExp("^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#\$%\^&\*])");

    labels = labels;
    loading = false;
    currentPage = PAGE_BASIC_PROFILE;
    @track profile = {
        howGetToCenter: '',
        language: language.replace('-', '_')
    };
    resendEmailCodeEnabled = true;
    emailVerificationsExhausted = false;
    resendSmsCodeEnabled = true;
    smsVerificationsExhausted = false;

    @api center;

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
        return (this.currentPage === PAGE_PICTURE);
    }

    get showPassword() {
        return (this.currentPage === PAGE_PASSWORD);
    }

    get showVerifyEmail() {
        return (this.currentPage === PAGE_VERIFY_EMAIL);
    }

    get showVerifyPhone() {
        return (this.currentPage === PAGE_VERIFY_PHONE);
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

    get suffixOptions() {
        return [
            {label: 'Jr', value: 'Jr'},
            {label: 'II', value: 'II'},
            {label: 'Sr', value: 'Sr'},
            {label: 'III', value: 'III'},
            {label: 'IV', value: 'IV'},
            {label: 'V', value: 'V'}
        ];
    }

    get stateOptions() {
        return [
            {label: 'AK', value: 'AK'},
            {label: 'AL', value: 'AL'},
            {label: 'AR', value: 'AR'},
            {label: 'AZ', value: 'AZ'},
            {label: 'CA', value: 'CA'},
            {label: 'CO', value: 'CO'},
            {label: 'CT', value: 'CT'},
            {label: 'DC', value: 'DC'},
            {label: 'DE', value: 'DE'},
            {label: 'FL', value: 'FL'},
            {label: 'GA', value: 'GA'},
            {label: 'HI', value: 'HI'},
            {label: 'IA', value: 'IA'},
            {label: 'ID', value: 'ID'},
            {label: 'IL', value: 'IL'},
            {label: 'IN', value: 'IN'},
            {label: 'KS', value: 'KS'},
            {label: 'KY', value: 'KY'},
            {label: 'LA', value: 'LA'},
            {label: 'MA', value: 'MA'},
            {label: 'MD', value: 'MD'},
            {label: 'ME', value: 'ME'},
            {label: 'MI', value: 'MI'},
            {label: 'MN', value: 'MN'},
            {label: 'MO', value: 'MO'},
            {label: 'MS', value: 'MS'},
            {label: 'MT', value: 'MT'},
            {label: 'NC', value: 'NC'},
            {label: 'ND', value: 'ND'},
            {label: 'NE', value: 'NE'},
            {label: 'NH', value: 'NH'},
            {label: 'NJ', value: 'NJ'},
            {label: 'NM', value: 'NM'},
            {label: 'NV', value: 'NV'},
            {label: 'NY', value: 'NY'},
            {label: 'OH', value: 'OH'},
            {label: 'OK', value: 'OK'},
            {label: 'OR', value: 'OR'},
            {label: 'PA', value: 'PA'},
            {label: 'RI', value: 'RI'},
            {label: 'SC', value: 'SC'},
            {label: 'SD', value: 'SD'},
            {label: 'TN', value: 'TN'},
            {label: 'TX', value: 'TX'},
            {label: 'UT', value: 'UT'},
            {label: 'VA', value: 'VA'},
            {label: 'VT', value: 'VT'},
            {label: 'WA', value: 'WA'},
            {label: 'WI', value: 'WI'},
            {label: 'WV', value: 'WV'},
            {label: 'WY', value: 'WY'}
        ];
    }

    get basicProfileValid() {
        return (
            util.isNotBlank(this.profile.firstName) &&
            util.isNotBlank(this.profile.lastName) &&
            util.isNotBlank(this.profile.email) &&
            util.isNotBlank(this.profile.mobilePhone)
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
            this.passwordRegex.test(this.profile.password) &&
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

    onFieldChange(event) {
        let field = event.target?.dataset?.field;

        this.profile[field] = event.detail?.value;
    }

    onPasswordChange(event) {
        this.onPasswordConfirmChange(event);

        let passwordInput = this.template.querySelector('lightning-input[data-field="password"]');

        if (!this.passwordRegex.test(this.profile.password)) {
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
        this.loading = true;

        const request = {
            profile: this.profile
        };

        console.log('upsertLead request', JSON.stringify(request));

        upsertLead(request).then(response => {
            console.log('upsertLead response', response);
            this.profile.id = response;

            this.currentPage = PAGE_ADDRESS;
        }).catch((error) => {
            util.showGuestToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    onAddressPreviousButtonClick() {
        this.loading = true;

        const request = {
            profile: this.profile
        };

        console.log('upsertLead request', JSON.stringify(request));

        upsertLead(request).then(response => {
            console.log('upsertLead response', response);

            this.currentPage = PAGE_BASIC_PROFILE;
        }).catch((error) => {
            util.showGuestToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    onAddressNextButtonClick() {
        this.loading = true;

        const request = {
            profile: this.profile
        };

        console.log('upsertLead request', JSON.stringify(request));

        upsertLead(request).then(response => {
            console.log('upsertLead response', response);

            this.currentPage = PAGE_PICTURE;
        }).catch((error) => {
            util.showGuestToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
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
        this.currentPage = PAGE_ADDRESS;
    }

    onPictureNextButtonClick() {
        this.currentPage = PAGE_PASSWORD;
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
                console.log('out of attempts');
            }
        }).catch((error) => {
            util.showGuestToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });

        this.profile.emailCode = '';
    }

    onVerifyEmailSkipButtonClick() {
        this.loading = true;

        const request = {
            profile: this.profile
        };

        console.log('sendVerificationSms request', JSON.stringify(request));

        sendVerificationSms(request).then(response => {
            console.log('sendVerificationSms response', response);
            this.currentPage = PAGE_VERIFY_PHONE;
        }).catch((error) => {
            util.showGuestToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
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
                sendVerificationSms(request).then(response => {
                    console.log('sendVerificationSms response', response);
                    this.currentPage = PAGE_VERIFY_PHONE;
                }).catch((error) => {
                    util.showGuestToast(this, 'error', labels.error, error);
                }).finally(() => {
                    this.loading = false;
                });
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
            startUrl: '/s/schedule'
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

}