@IsTest
public without sharing class CancelCardControllerTest {
    @TestSetup
    static void createTestData() {
        Account donorAccountRecord = TestUtil.createDonor('123-456');
        insert donorAccountRecord;

        Contact donorContactRecord = [SELECT Id FROM Contact WHERE AccountId = :donorAccountRecord.Id LIMIT 1];

        Payment_Method__c testPaymentMethod = new Payment_Method__c();
        testPaymentMethod.Name = 'Test Payment Method';
        testPaymentMethod.Donor__c = donorContactRecord.Id;
        testPaymentMethod.Account_Token__c = '1050';
        testPaymentMethod.Account_Number__c = '4968712468235235';
        testPaymentMethod.Card_Number__c = '7890';
        testPaymentMethod.Is_Active__c = true;
        testPaymentMethod.isDefault__c = true;
        insert testPaymentMethod;
    }
    
    @IsTest
    static void testGetDonorDefaultPaymentMethod() {
        Contact testDonor = [SELECT Id, AccountId, (SELECT Id, Name, Card_Number__c FROM Payment_Methods__r ORDER BY CreatedDate DESC LIMIT 1) FROM Contact WHERE Account.DonorId__c != null LIMIT 1];
        CancelCardController.PaymentMethod foundPaymentMethod;

        Test.startTest();
        foundPaymentMethod = CancelCardController.getDonorDefaultPaymentMethod(testDonor.AccountId);
        Test.stopTest();

        Assert.areEqual(foundPaymentMethod.id, testDonor.Payment_Methods__r[0].Id);
        Assert.areEqual(foundPaymentMethod.name, testDonor.Payment_Methods__r[0].Name);
        Assert.areEqual(foundPaymentMethod.cardNumber4Digits, testDonor.Payment_Methods__r[0].Card_Number__c.left(4));
    }

    @IsTest
    static void testCancelDonorActivePayment() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createAdminUser()) {
            Payment_Method__c testPaymentMethod = new Payment_Method__c();
            testPaymentMethod.Name = 'Test Payment Method';
            testPaymentMethod.Donor__c = experienceUser.ContactId;
            testPaymentMethod.Account_Token__c = '1050';
            testPaymentMethod.Account_Number__c = '4968712468235235';
            testPaymentMethod.Card_Number__c = '7890';
            testPaymentMethod.Is_Active__c = true;
            testPaymentMethod.isDefault__c = true;
            insert testPaymentMethod;
        }

        Test.setMock(HttpCalloutMock.class, new OnbeWsManageCardHttpCalloutMock());

        Test.startTest();
        System.runAs(experienceUser) {
            CancelCardController.cancelDonorActivePayment();
        }
        Test.stopTest();

        Payment_Method__c updatedPaymentMethod = [SELECT Id, Is_Active__c, isDefault__c FROM Payment_Method__c WHERE Donor__c = :experienceUser.ContactId ORDER BY CreatedDate DESC LIMIT 1];

        Assert.isFalse(updatedPaymentMethod.Is_Active__c);
        Assert.isFalse(updatedPaymentMethod.isDefault__c);
    }

    @IsTest 
    static void testCancelPaymentMethod() {
        Contact testDonor = [SELECT Id, (SELECT Id FROM Payment_Methods__r WHERE Is_Active__c = true AND isDefault__c = true ORDER BY CreatedDate DESC LIMIT 1) FROM Contact WHERE Account.DonorId__c != null LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new OnbeWsManageCardHttpCalloutMock());

        Test.startTest();
        CancelCardController.cancelPaymentMethod(testDonor.Payment_Methods__r[0].Id, Constants.ONBE_REISSUE_CARD_REVOKED_CODE);
        Test.stopTest();

        Payment_Method__c updatedPaymentMethod = [SELECT Id, Is_Active__c, isDefault__c FROM Payment_Method__c WHERE Id = :testDonor.Payment_Methods__r[0].Id LIMIT 1];

        Assert.isFalse(updatedPaymentMethod.Is_Active__c);
        Assert.isFalse(updatedPaymentMethod.isDefault__c);
    }
}