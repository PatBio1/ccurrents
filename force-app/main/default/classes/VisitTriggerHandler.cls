public with sharing class VisitTriggerHandler extends TriggerFactory.BaseHandler {
    public override void beforeInsert(List<SObject> newList) {
        VisitTriggerHelper.updateAppointmentDateTime((List<Visit__c>) newList);
        VisitTriggerHelper.updateDonorVisitDates((List<Visit__c>) newList);
    }
    
    public override void beforeUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        VisitTriggerHelper.updateAppointmentDateTime((List<Visit__c>) newMap.values());
        VisitTriggerHelper.updateDonorVisitDates((List<Visit__c>) newMap.values());
    }
}