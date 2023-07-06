/**
 * Created by joshlequire1 on 7/5/23.
 */

trigger PaymentRequestTrigger on Payment_Request__c (after insert, after update) {
    TriggerFactory.dispatchHandler(Visit__c.SObjectType, new PaymentRequestTriggerHandler());
}