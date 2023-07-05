/**
 * Created by joshlequire1 on 7/5/23.
 */

public without sharing class PaymentRequestTriggerHandler extends TriggerFactory.BaseHandler {

    public override void afterInsert(Map<Id, SObject> newMap) {
        et4ae5.triggerUtility.automate('Payment_Request__c');
    }

    public override void afterUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        et4ae5.triggerUtility.automate('Payment_Request__c');
    }

}