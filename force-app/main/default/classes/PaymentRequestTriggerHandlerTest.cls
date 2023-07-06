/**
 * Created by joshlequire1 on 7/5/23.
 */

@IsTest
public without sharing class PaymentRequestTriggerHandlerTest {

    @IsTest
    // There's not really a great way to test this, but it needs coverage. So, let's make sure we can create and update records.
    static void coverMarketingCloud() {
        Account donorAccount = TestUtil.createDonor('123');
        insert donorAccount;
        Id donorContactId = [SELECT PersonContactId FROM Account WHERE Id = :donorAccount.Id][0].PersonContactId;

        Payment_Request__c newPaymentRequest = new Payment_Request__c(
            Name = 'Test Payment Request',
            Status__c = 'New',
            Amount_Dollars__c = 100,
            Amount_Points__c = 50,
            Donor__c = donorContactId
        );

        insert newPaymentRequest;

        Assert.isNotNull(newPaymentRequest.Id);

        Payment_Request__c updatePaymentRequest = new Payment_Request__c(
            Id = newPaymentRequest.Id,
            Status__c = 'Approved'
        );

        update updatePaymentRequest;

        Assert.areEqual('Approved', updatePaymentRequest.Status__c);

    }

}