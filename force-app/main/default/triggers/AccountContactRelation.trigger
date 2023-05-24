trigger AccountContactRelation on AccountContactRelation (after insert) {

    TriggerFactory.dispatchHandler(AccountContactRelation.SObjectType, new AccountContactRelationTriggerHandler());

}