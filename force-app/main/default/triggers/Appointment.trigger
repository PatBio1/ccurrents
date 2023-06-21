trigger Appointment on Appointment__c (before insert, before update) {

    TriggerFactory.dispatchHandler(Appointment__c.SObjectType, new AppointmentTriggerHandler());

}