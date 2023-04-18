@IsTest
public class VisitSelectorTest {
    final static Integer NUMBER_OF_TEST_VISITS = 5;

    @TestSetup
    static void createTestData() {
        // Account of type center
        Account center = new Account();
        center.Name = 'Test Center';
        center.RecordTypeId = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Center' LIMIT 1].Id;
        insert center;

        // Donation Type
        Donation_Type__c donationType = new Donation_Type__c();
        donationType.Name = 'Test Donation Type';
        insert donationType;

        // Center Donation Type
        Center_Donation_Type__c centerDonationType = new Center_Donation_Type__c();
        centerDonationType.Center__c = center.Id;
        centerDonationType.Donation_Type__c = donationType.Id;
        centerDonationType.isActive__c = true;
        insert centerDonationType;

        Account testDonor = TestUtil.createTestDonor(ScheduleUtils.createFirstVisitCode());
        insert testDonor;

        List<Visit__c> visits = new List<Visit__c>();
        Contact testDonorContact = [SELECT Id FROM Contact WHERE AccountId = :testDonor.Id LIMIT 1];

        for(Integer i = 0; i < NUMBER_OF_TEST_VISITS; i++) {
            Visit__c visit = new Visit__c();
            visit.Donor__c = testDonorContact.Id;
            visit.Center_Donation_Type__c = centerDonationType.Id;
            visit.Status__c = 'Scheduled';
            visits.add(visit);
        }
        insert visits;
    }

    @IsTest
    static void testVisitSelector() {
        Integer numberOfVisits;
        
        Test.startTest();
        System.runAs(TestUtil.createExperienceUserFromContactId([SELECT Id FROM Contact LIMIT 1].Id)) {
            numberOfVisits = VisitSelector.getCurrentDonorVisitCount();
        }
        Test.stopTest();

        Assert.areEqual(NUMBER_OF_TEST_VISITS, numberOfVisits, 'Number of visits should be ' + NUMBER_OF_TEST_VISITS);
    }
}