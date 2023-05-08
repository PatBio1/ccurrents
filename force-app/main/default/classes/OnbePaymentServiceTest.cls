@isTest
public with sharing class OnbePaymentServiceTest {

    @isTest
    private static void callPaymentServiceMethods_positive() {

        OnbePaymentService onbePayService = new OnbePaymentService();

        Id donorId = Id.valueOf('001xa000003DIlo');
        Decimal amount = 50.00;

        // return Service method strings and assert
        System.assertEquals('Onbe', onbePayService.getPaymentServiceName(), 'Payment Service Name did not match expected value.');
        System.assertEquals('Onbe Payment Service supports stored value card transfers.', onbePayService.getPaymentServiceDescription(), 'Payment Service Description did not match expected value.');
        System.assertEquals('Onbe Physical Card Link', onbePayService.linkPhysicalCard(), 'Payment Physical Card Link did not match expected value.');
        System.assertEquals('Onbe Balance', onbePayService.getBalance(), 'getBalance() method did not return expected value.');
        System.assertEquals('Onbe Transaction', onbePayService.getTransaction(), 'getTransaction() method did not return expected value.');
        System.assertEquals('Onbe Transaction History', onbePayService.getTransactionHistory(), 'getTransactionHistory() method did not return expected value.');
    }

    @isTest
    private static void testSetupPaymentServiceAccount() {
        Account testDonorAccount = TestUtil.createDonor('123-123');
        insert testDonorAccount;

        Contact testDonor = [SELECT Id FROM Contact WHERE AccountId = :testDonorAccount.Id LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        OnbePaymentService onbePayService = new OnbePaymentService();
        onbePayService.setupPaymentServiceAccount('1040', testDonor.Id, 0, '1234');
        Test.stopTest();

        Assert.areEqual(1, [SELECT count() FROM Payment_Method__c WHERE Donor__c = :testDonor.Id], 'Payment Method was not created.');
    }

    @isTest 
    private static void testProcessPayment() {
        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        OnbePaymentService onbePayService = new OnbePaymentService();
        onbePayService.processPayment('4968712468235235', 'Test Comment 1', 50000);
        Test.stopTest();
    }

    @isTest
    private static void testUpdateAccountStatus() {
        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        OnbePaymentService onbePayService = new OnbePaymentService();
        // onbePayService.updateAccountStatus('CLOSED');
        Test.stopTest();
    }
}