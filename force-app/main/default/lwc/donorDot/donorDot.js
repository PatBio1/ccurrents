import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import { visitStatusToDisplayClass, visitOutcomeToDisplayClass } from "c/constants";

export default class DonorDot extends NavigationMixin(LightningElement)  {
    @track showpopover = false;
    @api initials;
    @api icon = 'standard:account';
    @api donor;
    @api appointment;
    @api popFlipYPoint;

    donorLink;
    visitLink;
    isPopupConfigured = false;
    popUpDirection;

    get canReschedule() {
        return (!this.appointment.isInThePast);
    }

    get displayStatus() {
        return (this.donor.outcome) ? this.donor.outcome : this.donor.status;
    }

    get cantCancelVisit() {
        return (this.donor.status === "Complete" || this.donor.outcome === "Canceled");
    }

    get popupContainerClasses() {
        let baseClasses = ["slds-popover", "visit-popup-container"];

        if (this.popUpDirection === "Top") {
            baseClasses.push("slds-nubbin_bottom");
        } else {
            baseClasses.push("slds-nubbin_top");
        }

        return baseClasses.join(" ");
    }

    get avatarClasses() {
        let targetClasses = ['slds-m-right_small', 'donor-icon'];
        
        if (this.donor.outcome) {
            targetClasses.push(visitOutcomeToDisplayClass.get(this.donor.outcome));
        } else {
            targetClasses.push(visitStatusToDisplayClass.get(this.donor.status));
        }

        return targetClasses.join(" ");
    }

    get loyaltyBadgeDisplayClass() {
        const loyaltyLevelNameToClass = new Map([
            ["Donor (Default)", "regular-loyalty-badge"],
            ["Normal Donor +15", "regular-loyalty-badge"],
            ["Signature", "signature-loyalty-badge"],
            ["VIP", "vip-loyalty-badge"],
            ["Royal", "royal-loyalty-badge"]
        ]);

        return ["loyalty-badge", loyaltyLevelNameToClass.get(this.donor.loyaltyTierName) || "regular-loyalty-badge"].join(" ");
    }

    get isFirstVisit() {
        return this.donor.isFirstVisit;
    }

    get displaySpecialTasks() {
        if (this.isFirstVisit) {
            return false;
        }

        return (this.donor.visitNotes && this.donor.visitNotes.length > 0);
    }

    connectedCallback() {
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.donor.visitId,
                actionName: 'view',
            },
        }).then((url) => {
            this.visitLink = url;
        });

        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.donor.donorId,
                actionName: 'view',
            },
        }).then((url) => {
            this.donorLink = url;
        });
    }

    renderedCallback() {
        if (this.showpopover && !this.isPopupConfigured) {
            this.calculatePopupPosition();
        }
    }

    togglePopover() {
        this.showpopover = !this.showpopover;
        this.isPopupConfigured = false;
    }

    hidePopover() {
        this.showpopover = false;
    }

    dragstart(event){
        this.showpopover = false;

        event.dataTransfer.setData("donorId", this.donor.donorId);
        event.dataTransfer.setData("donorName", this.donor.donorName);
        event.dataTransfer.setData("appointmentId", this.appointment.Id);
        event.dataTransfer.setData("appointmentTime", this.appointment.timeString);
        event.dataTransfer.setData("visitId", this.donor.visitId );
    }

    cancelVisit(event){
        const cancelVisitEvent = new CustomEvent("cancelvisit", {
            detail: {
                visitId:this.donor.visitId,
                appointmentId: this.appointment.Id,
                donorName: this.donor.donorName
            }
        });

        this.dispatchEvent(cancelVisitEvent);
    }

    calculatePopupPosition() {
        let popupContainer = this.template.querySelector("section.visit-popup-container");
        if (!popupContainer) {
            console.error("Couldn't find popup container");
            return;
        }

        let popOnTop = (this.template.host.getBoundingClientRect().y >= this.popFlipYPoint);
        if (popOnTop) {
            this.popUpDirection = "Top";
            popupContainer.style.top = "-218px";
        } else {
            this.popUpDirection = "Bottom";
            popupContainer.style.top = "66px";
        }

        this.isPopupConfigured = true;
    }
}