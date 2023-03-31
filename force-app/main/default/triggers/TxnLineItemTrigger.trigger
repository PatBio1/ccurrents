trigger TxnLineItemTrigger on Txn_Line_Item__c (before insert, before update) {
    TriggerFactory.dispatchHandler(Txn_Line_Item__c.SObjectType, new TxnLineItemTriggerHandler());
}