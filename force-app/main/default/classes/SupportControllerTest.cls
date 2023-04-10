@IsTest
public with sharing class SupportControllerTest {
    final static String TEST_EMAIL = 'supporttest@email.com';
    final static String TEST_PHONE = '1234567890';
    
    @TestSetup
    static void createTestData() {
        insert new Support_Contact_Information__c(
            Contact_Email__c = TEST_EMAIL,
            Contact_Phone__c = TEST_PHONE
        );
    }
    
    @isTest static void testCreateSupportCaseForUser() {
        String testMessage = 'This is a test message for a case!';
        User testUser = TestUtil.createExperienceUser();

        Test.startTest();
        System.runAs(testUser) {
            SupportController.createSupportCaseForUser(testMessage);
        }
        Test.stopTest();

        Case targetCustomerSupportCase = [SELECT Id, Subject, Description, Origin, Reason, ContactId FROM Case WHERE ContactId = :testUser.ContactId LIMIT 1];

        Assert.isNotNull(targetCustomerSupportCase);
        Assert.areEqual(Constants.DEFAULT_CUSTOMER_SUPPORT_CASE_SUBJECT, targetCustomerSupportCase.Subject, 'Customer Support Subjects should default to ' + Constants.DEFAULT_CUSTOMER_SUPPORT_CASE_SUBJECT);
        Assert.areEqual(testMessage, targetCustomerSupportCase.Description, 'Customer Support Descriptions should be set to the message passed in');
        Assert.areEqual(Constants.DEFAULT_CUSTOMER_SUPPORT_CASE_ORIGIN, targetCustomerSupportCase.Origin, 'Customer Support Origins should default to ' + Constants.DEFAULT_CUSTOMER_SUPPORT_CASE_ORIGIN);
        Assert.areEqual(Constants.DEFAULT_CUSTOMER_SUPPORT_CASE_REASON, targetCustomerSupportCase.Reason, 'Customer Support Reasons should default to ' + Constants.DEFAULT_CUSTOMER_SUPPORT_CASE_REASON);
        Assert.areEqual(testUser.ContactId, targetCustomerSupportCase.ContactId, 'Customer Support Cases should be associated with the user\'s contact');
    }

    @isTest static void testFetchSupportContactInformation() {
        Test.startTest();
        SupportController.ContactInformation supportContactInformation = SupportController.fetchSupportContactInformation();
        Test.stopTest();

        Assert.isNotNull(supportContactInformation);
        Assert.areEqual(TEST_EMAIL, supportContactInformation.contactEmail, 'Support Contact Information Email should be ' + TEST_EMAIL);
        Assert.areEqual(TEST_PHONE, supportContactInformation.contactPhone, 'Support Contact Information Phone should be ' + TEST_PHONE);
    }
}