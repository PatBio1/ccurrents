import { track, LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import labels from 'c/labelService';
import util from 'c/util';
import getCenterRate from '@salesforce/apex/RateSelector.getCenterRate';
import getCurrentDonorVisitCount from '@salesforce/apex/VisitSelector.getCurrentDonorVisitCount';
import getCenter from '@salesforce/apex/SchedulerController.getCenter';
import getAppointments from '@salesforce/apex/SchedulerController.getAppointments';
import scheduleVisit from '@salesforce/apex/SchedulerController.scheduleVisit';
import rescheduleVisit from '@salesforce/apex/SchedulerController.rescheduleVisit';
import getDonorRewardsInfo from '@salesforce/apex/DonorSelector.getDonorRewardsInfo';

export default class Scheduler extends NavigationMixin(LightningElement) {

    @wire(CurrentPageReference) pageRef;

    labels = labels;
    currentPage = 'Scheduler';
    loading = true;
    appointmentDate;
    donorPoints;
    donorCurrency;
    center = {};
    centerRateInfo;
    @track appointmentGroups = [];

    existingVisitCount;
    appointmentSelected = false;

    get submitButtonLabel() {
        if (this.isInRescheduleMode) {
            return labels.rescheduleAction;
        }

        return labels.schedule;
    }

    get isInRescheduleMode() {
        return (this.pageRef && this.pageRef.state && this.pageRef.state.rescheduleVisitId);
    }

    get hasCenterRateInfo() {
        return (this.centerRateInfo !== undefined);
    }

    get screenTitle() {
        if (this.isInRescheduleMode) {
            return labels.rescheduleVisitTitle;
        }

        if (!this.existingVisitCount) {
            return labels.scheduleYour1stAppointment;
        }

        return labels.scheduleYourAppointment;
    }

    get hasRewardInfo() {
        return (this.donorPoints !== undefined && this.donorCurrency !== undefined);
    }

    get showScheduler() {
        return (this.currentPage === 'Scheduler');
    }

    get showCenter() {
        return (this.currentPage === 'Center');
    }

    connectedCallback() {
        const now = new Date();
        const day = ('0' + now.getDate()).slice(-2);
        const month = ('0' + (now.getMonth() + 1)).slice(-2);
        const year = now.getFullYear();

        this.appointmentDate = year + '-' + month + '-' + day;

        this.loadExistingVisitCount();
        this.loadCenter();
        this.loadDonorRewardsInfo();
    }

    renderedCallback() {
        console.log(this.pageRef);
    }

    onAppointmentDateChange(event) {
        this.appointmentDate = event.detail.value;

        this.loadAppointments();
    }

    onViewCenterClick() {
        this.currentPage = 'Center';
    }

    onCenterBackButtonClick() {
        this.currentPage = 'Scheduler';
    }

    onChooseAnotherCenterClick(event) {
        event.preventDefault();
    }

    onAppointmentButtonClick(event) {
        let index = event.target.dataset.index;
        let groupIndex = event.target.dataset.groupIndex;
        let appointmentGroup = this.appointmentGroups[groupIndex];
        let appointment = appointmentGroup.appointments[index];

        const previouslySelected = appointment.selected;

        this.appointmentGroups.forEach((appointmentGroup) => {
            appointmentGroup.appointments.forEach((appointment) => {
                appointment.selected = false;
                appointment.classes = 'appointment-button';
            });
        });

        appointment.selected = !previouslySelected;
        appointment.classes = 'appointment-button ' + (appointment.selected ? 'selected' : '');

        this.appointmentSelected = appointment.selected;
    }

    onCancelButtonClick() {
        util.navigateToPage(this, 'Appointments__c');
    }

    onScheduleButtonClick() {
        this.loading = true;

        let selectedAppointment;

        this.appointmentGroups.forEach((appointmentGroup) => {
            appointmentGroup.appointments.forEach((appointment) => {
                if (appointment.selected) {
                    selectedAppointment = appointment;
                }
            });
        });

        const request = { appointmentId: selectedAppointment.id }
        if (this.isInRescheduleMode) {
            request.originalVisitId = this.pageRef.state.rescheduleVisitId;
            console.log('reschedule request', JSON.stringify(request));

            rescheduleVisit(request).then(response => {
                console.log('response', response);

                util.navigateToPage(this, 'Appointments__c');
            }).catch((error) => {
                util.showToast(this, 'error', labels.error, error);
            }).finally(() => {
                this.loading = false;
            });
        } else {
            console.log('schedule request', JSON.stringify(request));

            scheduleVisit(request).then(response => {
                console.log('response', response);

                util.navigateToPage(this, 'Appointments__c');
            }).catch((error) => {
                util.showToast(this, 'error', labels.error, error);
            }).finally(() => {
                this.loading = false;
            });
        }
    }

    loadCenter() {
        this.loading = true;

        getCenter().then(response => {
            console.log('response', response);
            this.center = response;

            this.loadCenterRate();
            this.loadAppointments();
        }).catch((error) => {
            util.showToast(this, 'error', labels.error, error);
            this.loading = false;
        });
    }

    loadAppointments() {
        this.loading = true;

        const request = {
            centerId: this.center.id,
            appointmentDate: this.appointmentDate
        };

        console.log('request', JSON.stringify(request));

        getAppointments(request).then(response => {
            console.log('response', response);

            this.appointmentGroups = response;

            this.appointmentGroups.forEach((appointmentGroup) => {
                appointmentGroup.appointments.forEach((appointment) => {
                    appointment.classes = 'appointment-button';
                    appointment.available = (appointment.availability > 0);
                });
            });
        }).catch((error) => {
            util.showToast(this, 'error', labels.error, error);
        }).finally(() => {
            this.loading = false;
        });
    }

    async loadDonorRewardsInfo() {
        this.loading = true;

        try {
            let response = await getDonorRewardsInfo();
            console.log("loadDonorRewardsInfo", response);

            this.donorCurrency = response.donorBalance;
            this.donorPoints = response.donorPoints;
        } catch (error) {
            util.showToast(this, 'error', labels.error, error);
        } finally {
            this.loading = false;
        }
    }

    async loadExistingVisitCount() {
        this.loading = true;

        try {
            this.existingVisitCount = await getCurrentDonorVisitCount();
        } catch (error) {
            util.showToast(this, 'error', labels.error, error);
        } finally {
            this.loading = false;
        }
    }

    async loadCenterRate() {
        try {
            this.centerRateInfo = await getCenterRate({ centerId: this.center.id, targetDonationType: 'Normal Source Plasma' });
        } catch (error) {
            util.showToast(this, 'error', labels.error, error);
        }
    }

}