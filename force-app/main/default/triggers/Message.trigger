trigger Message on Message__c (after insert) {

    TriggerFactory.dispatchHandler(Message__c.SObjectType, new MessageTriggerHandler());

}