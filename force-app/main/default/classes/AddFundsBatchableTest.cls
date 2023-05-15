@IsTest
public without sharing class AddFundsBatchableTest {

    @TestSetup
    static void createTestData() {
        List<Account> testDonors = new List<Account> {
            TestUtil.createDonor('123-123'),
            TestUtil.createDonor('456-456'),
            TestUtil.createDonor('789-789')
        };
        insert testDonors;

        Account testCenter = Testutil.createMiramarCenter();
        insert testCenter;

        Schedule__c testSchedule = TestUtil.createTestSchedule(testCenter.Id, Datetime.now());
        insert testSchedule;

        Appointment__c testAppointment = TestUtil.createTestAppointment(testSchedule.Id, Datetime.now());
        insert testAppointment;

        Center_Donation_Type__c testCenterDonationType = TestUtil.createCenterDonationType(testCenter.Id);
        insert testCenterDonationType;

        List<Visit__c> testVisits = new List<Visit__c>();
        for(Contact testDonorContact : [SELECT Id FROM Contact WHERE AccountId IN :testDonors]) {
            testVisits.add(new Visit__c(
                Donor__c = testDonorContact.Id,
                Appointment__c = testAppointment.Id,
                Center_Donation_Type__c = testCenterDonationType.Id,
                Status__c = 'Complete',
                Outcome__c = 'Donation'
            ));
        }
        insert testVisits;
    }

    @IsTest
    static void testSuccessfulAddFundsRun() {
        List<Contact> testDonors = [SELECT Id, (SELECT Id FROM Visits__r) FROM Contact WHERE Account.DonorId__c != null];
        List<DonorCompInvocable.AddFundsRequest> addFundsRequests = new List<DonorCompInvocable.AddFundsRequest>();
        Integer index = 0;

        for(Contact testDonor : testDonors) {
            DonorCompInvocable.AddFundsRequest newAddFundsRequest = new DonorCompInvocable.AddFundsRequest(testDonor.Id, testDonor.Visits__r[0].Id, '001000000000001');
            newAddFundsRequest.comments = new List<String> { 'Test Comment ' + index };
            newAddFundsRequest.total = 100.00;

            addFundsRequests.add(newAddFundsRequest);
            index++;
        }

        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        Database.executeBatch(new AddFundsBatchable(addFundsRequests));
        Test.stopTest();
    }
}