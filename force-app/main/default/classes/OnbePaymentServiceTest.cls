@isTest
public with sharing class OnbePaymentServiceTest {

    @TestSetup
    static void createTestData() {
        Account testDonorAccount = TestUtil.createDonor('123-123');
        insert testDonorAccount;

        testDonorAccount.PersonMobilePhone = '123-123-1234';
        testDonorAccount.PersonMailingStreet = '123 Test St.';
        testDonorAccount.PersonMailingCity = 'Test City';
        testDonorAccount.PersonMailingState = 'TX';
        testDonorAccount.PersonMailingPostalCode = '12345';
        testDonorAccount.PersonMailingCountry = 'US';
        update testDonorAccount;
    }

    @isTest
    private static void callPaymentServiceMethods_positive() {
        OnbePaymentService onbePayService = new OnbePaymentService();

        // return Service method strings and assert
        System.assertEquals('Onbe', onbePayService.getPaymentServiceName(), 'Payment Service Name did not match expected value.');
        System.assertEquals('Onbe Payment Service supports stored value card transfers.', onbePayService.getPaymentServiceDescription(), 'Payment Service Description did not match expected value.');
        System.assertEquals('Onbe Transaction', onbePayService.getTransaction(), 'getTransaction() method did not return expected value.');
        System.assertEquals('Onbe Transaction History', onbePayService.getTransactionHistory(), 'getTransactionHistory() method did not return expected value.');
    }

    @isTest
    private static void testSetupPaymentServiceAccount() {
        Contact testDonor = [SELECT Id FROM Contact WHERE Account.DonorId__c != null LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        OnbePaymentService onbePayService = new OnbePaymentService();
        onbePayService.setupPaymentServiceAccount('1040', testDonor.Id, 0, '1234', false);
        Test.stopTest();

        Payment_Method__c newPaymentMethod = [SELECT Id, Account_Token__c, Partner_User_Id__c, Is_Active__c FROM Payment_Method__c WHERE Donor__c = :testDonor.Id LIMIT 1];

        Assert.isNotNull(newPaymentMethod, 'Payment Method was not created.');
        Assert.areEqual(testDonor.Id, newPaymentMethod.Partner_User_Id__c, 'Partner User Id was not set correctly.');
        Assert.areEqual('1040', newPaymentMethod.Account_Token__c, 'Account Token was not set correctly.');
        Assert.isTrue(newPaymentMethod.Is_Active__c, 'Is Active was not set to true.');
    }

    @isTest 
    private static void testProcessPayment() {
        Contact testDonor = [SELECT Id FROM Contact WHERE Account.DonorId__c != null LIMIT 1];
        
        Payment_Method__c testPaymentMethod = new Payment_Method__c();
        testPaymentMethod.Name = 'Test Payment Method';
        testPaymentMethod.Donor__c = testDonor.Id;
        testPaymentMethod.Account_Token__c = '1050';
        testPaymentMethod.Account_Number__c = '4968712468235235';
        testPaymentMethod.Card_Number__c = '7890';
        testPaymentMethod.Is_Active__c = true;
        testPaymentMethod.isDefault__c = true;
        testPaymentMethod.Partner_User_Id__c = testDonor.Id;
        insert testPaymentMethod;
        
        Decimal targetAmount = 50.00;
        String comment = 'Test Comment 1';

        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        OnbePaymentService onbePayService = new OnbePaymentService();
        onbePayService.processPayment(testDonor.Id, comment, (Long)(targetAmount * 100), 'transaction-12476123');
        Test.stopTest();
    }

    @isTest
    private static void testUpdateAccountStatus() {
        Contact testDonor = [SELECT Id FROM Contact WHERE Account.DonorId__c != null LIMIT 1];

        Payment_Method__c testPaymentMethod = new Payment_Method__c();
        testPaymentMethod.Name = 'Test Payment Method';
        testPaymentMethod.Donor__c = testDonor.Id;
        testPaymentMethod.Account_Token__c = '1050';
        testPaymentMethod.Account_Number__c = '4968712468235235';
        testPaymentMethod.Card_Number__c = '7890';
        testPaymentMethod.Is_Active__c = true;
        testPaymentMethod.isDefault__c = true;
        testPaymentMethod.Partner_User_Id__c = testDonor.Id;
        insert testPaymentMethod;

        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        OnbePaymentService onbePayService = new OnbePaymentService();
        onbePayService.updateAccountStatus(testPaymentMethod.Id, 'CLOSED');
        Test.stopTest();
    }

    @isTest 
    private static void testGetBalance() {
        Contact testDonor = [SELECT Id FROM Contact WHERE Account.DonorId__c != null LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new OnbeWsManageCardHttpCalloutMock());

        Test.startTest();
        OnbePaymentService onbePayService = new OnbePaymentService();
        onbePayService.getBalance(testDonor.Id);
        Test.stopTest();
    }

    @isTest
    private static void testReissueCard() {
        Contact testDonor = [SELECT Id FROM Contact WHERE Account.DonorId__c != null LIMIT 1];

        Payment_Method__c testPaymentMethod = new Payment_Method__c();
        testPaymentMethod.Name = 'Test Payment Method';
        testPaymentMethod.Donor__c = testDonor.Id;
        testPaymentMethod.Account_Token__c = '1050';
        testPaymentMethod.Account_Number__c = '4968712468235235';
        testPaymentMethod.Card_Number__c = '7890';
        testPaymentMethod.Is_Active__c = true;
        testPaymentMethod.isDefault__c = true;
        testPaymentMethod.Partner_User_Id__c = testDonor.Id;
        insert testPaymentMethod;

        Test.setMock(HttpCalloutMock.class, new OnbeWsManageCardHttpCalloutMock());

        Test.startTest();
        OnbePaymentService onbePayService = new OnbePaymentService();
        onbePayService.reissueCard(testPaymentMethod.Id, Constants.ONBE_REISSUE_CARD_REVOKED_CODE);
        Test.stopTest();
    }

    @isTest 
    private static void testLinkPhysicalCard() {
        Contact testDonor = [SELECT Id FROM Contact WHERE Account.DonorId__c != null LIMIT 1];

        Payment_Method__c testPaymentMethod = new Payment_Method__c();
        testPaymentMethod.Name = 'Test Payment Method';
        testPaymentMethod.Donor__c = testDonor.Id;
        testPaymentMethod.Account_Token__c = '1050';
        testPaymentMethod.Account_Number__c = '4968712468235235';
        testPaymentMethod.Card_Number__c = '7890';
        testPaymentMethod.Is_Active__c = true;
        testPaymentMethod.isDefault__c = true;
        testPaymentMethod.Partner_User_Id__c = testDonor.Id;
        insert testPaymentMethod;

        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        OnbePaymentService onbePayService = new OnbePaymentService();
        onbePayService.linkPhysicalCard('1051', testDonor.Id, '1234', true);
        Test.stopTest();

        Assert.areEqual(2, [SELECT count() FROM Payment_Method__c WHERE Donor__c = :testDonor.Id], 'Payment Method was not created.');

        Payment_Method__c existingPaymentMethod = [SELECT Id, Is_Active__c FROM Payment_Method__c WHERE Donor__c = :testDonor.Id AND Account_Token__c = '1050'];
        Payment_Method__c newPaymentMethod = [SELECT Id, Account_Token__c, Is_Active__c, Partner_User_Id__c FROM Payment_Method__c WHERE Donor__c = :testDonor.Id AND Account_Token__c = '1051'];

        Assert.isFalse(existingPaymentMethod.Is_Active__c, 'Existing Payment Method was not deactivated.');
        Assert.areEqual('1051', newPaymentMethod.Account_Token__c, 'New Payment Method was not created.');
        Assert.areEqual(testDonor.Id, newPaymentMethod.Partner_User_Id__c, 'New Payment Method was not linked to the Donor.');
        Assert.isTrue(newPaymentMethod.Is_Active__c, 'New Payment Method was not activated.');
    }
}