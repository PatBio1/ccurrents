import { api, track, LightningElement } from 'lwc';
import labels from 'c/labelService';
import util from 'c/util';
import upsertLead from '@salesforce/apex/ProfileController.upsertLead';
import createUser from '@salesforce/apex/ProfileController.createUser';
import assignPermissionSet from '@salesforce/apex/ProfileController.assignPermissionSet';

export default class ClinicChooser extends LightningElement {

    minPasswordCharacters = 8;
    maxPasswordCharacters = 16;

    // At least 1 lowercase, 1 uppercase, 1 number and 1 special character.
    passwordRegex = new RegExp("^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#\$%\^&\*])");

    labels = labels;
    loading = false;
    currentPage = 'Basic Profile';
    @track profile = {
        howGetToCenter: ''
    };

    @api center;

    get showBasicProfile() {
        return (this.currentPage === 'Basic Profile');
    }

    get showAddress() {
        return (this.currentPage === 'Address');
    }

    get showPicture() {
        return (this.currentPage === 'Picture');
    }

    get showPassword() {
        return (this.currentPage === 'Password');
    }

    get showCongratulations() {
        return (this.currentPage === 'Congratulations');
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

    get pictureValid() {
        return true;
    }

    get passwordValid() {
        return (
            util.isNotBlank(this.profile.password) &&
            this.profile.password.length >= this.minPasswordCharacters &&
            this.passwordRegex.test(this.profile.password) &&
            this.profile.password.trim() === this.profile.passwordConfirm?.trim()
        );
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

            this.currentPage = 'Address';
        }).catch((error) => {
            console.log(error);
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

            this.currentPage = 'Basic Profile';
        }).catch((error) => {
            console.log(error);
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

            this.currentPage = 'Picture';
        }).catch((error) => {
            console.log(error);
        }).finally(() => {
            this.loading = false;
        });
    }

    onPicturePreviousButtonClick() {
        this.currentPage = 'Address';
    }

    onPictureNextButtonClick() {
        this.currentPage = 'Password';
    }

    onPasswordPreviousButtonClick() {
        this.currentPage = 'Picture';
    }

    onPasswordNextButtonClick() {
        this.loading = true;

        this.profile.centerId = this.center.id;

        const request = {
            profile: this.profile
        };

        console.log('createUser request', JSON.stringify(request));

        createUser(request).then(response => {
            console.log('createUser response', response);

            this.assignPermissions(response);
        }).catch((error) => {
            console.log(error);

            this.loading = false;
        });
    }

    onScheduleButtonClick() {
        location.href = '/ProesisDonor/s/schedule';
    }

    assignPermissions(userId) {
        const request = {
            userId: userId
        };

        console.log('assignPermissionSet request', JSON.stringify(request));

        assignPermissionSet(request).then(response => {
            this.currentPage = 'Congratulations';
        }).catch((error) => {
            console.log(error);
        }).finally(() => {
            this.loading = false;
        });
    }

}