trigger VisitTrigger on Visit__c (before insert, before update, after insert, after update) {
    TriggerFactory.dispatchHandler(Visit__c.SObjectType, new VisitTriggerHandler());
}