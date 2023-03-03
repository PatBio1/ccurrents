import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import { visitStatusToDisplayClass, visitOutcomeToDisplayClass } from "c/constants";

export default class DonorDot extends NavigationMixin(LightningElement)  {

    @track showpopover = false;
    @api initials;
    @api icon = 'standard:account';
    @api donor;
    @api appointment;
    filteredClass = '';
    donorLink;
    visitLink;
    dotclasses = [
        'slds-m-right_small',
        'donor-icon',

    ];


    get filteredClasses(){
        if(this.donor.filtered){
            this.filteredClass = 'filtered';
        }else{
            this.filteredClass = 'unfiltered';
        }
        return this.filteredClass;
    }

    get classes(){
        this.dotclasses.push(this.determineAvatarClass(this.donor.status));
        return this.dotclasses.join(' ');
    }

    renderedCallback(){
        console.log('rendered cb')
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

    togglePopover() {
        this.showpopover = !this.showpopover;
    }

    hidePopover() {
        this.showpopover = false;
    }

    donorClick(){

        window.open(this.donorLink);
        
    }

    visitClick(){
        window.open(this.visitLink);
    }

    dragstart(event){
        //save some "draggable" data
        this.showpopover = false;
        event.dataTransfer.setData("donorId", this.donor.donorId);
        event.dataTransfer.setData("donorName", this.donor.donorName);
        event.dataTransfer.setData("appointmentId", this.appointment.Id);
        event.dataTransfer.setData("appointmentTime", this.appointment.timeString);
        event.dataTransfer.setData("visitId", this.donor.visitId );
        console.log('dragging... donor visit '  + this.donor.donorId + 'from visit ' + this.donor.visitId +  ' from appointment ' + this.appointment.Id)
    }

    cancelVisit(event){
        console.log(this.donor.visitId);
        const cancelVisitEvent = new CustomEvent("cancelvisit", {
            detail: {
                visitId:this.donor.visitId,
                appointmentId: this.appointment.Id,
                donorName: this.donor.donorName
            }
        });
        this.dispatchEvent(cancelVisitEvent);
    }



    dragend(event){
        console.log('dragend...'+ this.donor.donorId );
    }

    determineAvatarClass() {
        let targetClasses = [visitStatusToDisplayClass.get(this.donor.status)];
        
        if (this.donor.outcome) {
            targetClasses.push(visitOutcomeToDisplayClass.get(this.donor.outcome));
        }

        return targetClasses.join(" ");
    }
 
}