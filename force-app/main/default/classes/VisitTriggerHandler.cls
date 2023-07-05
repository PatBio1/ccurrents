public with sharing class VisitTriggerHandler extends TriggerFactory.BaseHandler {
    public override void beforeInsert(List<SObject> newList) {
        VisitTriggerHelper.updateAppointmentDateTime((List<Visit__c>) newList);
        VisitTriggerHelper.updateDonorVisitDates((List<Visit__c>) newList);
    }

    public override void beforeUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        VisitTriggerHelper.updateAppointmentDateTime((List<Visit__c>) newMap.values());
        VisitTriggerHelper.updateDonorVisitDates((List<Visit__c>) newMap.values());
    }

    // These methods rely on the above two methods having been processed first in order to work properly
    public override void afterInsert(Map<Id, SObject> newMap) {
        VisitTriggerHelper.updateAppointmentBookedValues((Map<Id, Visit__c>) newMap, null);
        VisitTriggerHelper.manageVisitSpecialNotes((List<Visit__c>) newMap.values());
    }

    public override void afterUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        VisitTriggerHelper.updateAppointmentBookedValues((Map<Id, Visit__c>) newMap, (Map<Id, Visit__c>) oldMap);
        VisitTriggerHelper.manageVisitSpecialNotes((List<Visit__c>) newMap.values());
    }

    public override void afterDelete(Map<Id, SObject> oldMap) {
        VisitTriggerHelper.updateAppointmentBookedValues((Map<Id, Visit__c>) oldMap, null);
    }
}