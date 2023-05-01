@IsTest
public class DonorBatchableTest {
    static final Integer EXPECTED_VISIT_PER_CONTACT = 3;
    static final String VIP_LEVEL_NAME = 'VIP';

    @TestSetup
    static void makeTestData() {
        Level__c vipLevel = new Level__c(Name = VIP_LEVEL_NAME, Donation_Threshold__c = (EXPECTED_VISIT_PER_CONTACT - 1), isActive__c = true, isVisible__c = true);
        insert vipLevel;

        Level__c baseLevel = new Level__c(Name = 'Base Level', Donation_Threshold__c = 0, isActive__c = true, isVisible__c = true, Next_Level__c = vipLevel.Id);
        insert baseLevel;

        String targetCenterRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Center').getRecordTypeId();

        List<Contact> contacts = new List<Contact>();
        for(Integer i = 0; i < 200; i++) {
            contacts.add(new Contact(
                FirstName = 'Test' + i,
                LastName = 'Contact' + i,
                Loyalty_Level__c = baseLevel.Id
            ));
        }
        insert contacts;

        Account testCenter = new Account(Name = 'Test Center', RecordTypeId = targetCenterRecordTypeId);
        insert testCenter;

        Donation_Type__c testDonationType = new Donation_Type__c(Name = 'Test Donation Type');
        insert testDonationType;

        Center_Donation_Type__c testCenterDonationType = new Center_Donation_Type__c(
            Center__c = testCenter.Id,
            Donation_Type__c = testDonationType.Id
        );
        insert testCenterDonationType;

        List<Visit__c> visits = new List<Visit__c>();
        for(Contact contact : contacts) {
            // Eligible Visists
            for(Integer i = 0; i < 3; i++) {
                visits.add(new Visit__c(
                    Donor__c = contact.Id,
                    Appointment_Datetime__c = Datetime.now(),
                    Status__c = 'Complete',
                    Outcome__c = 'Donation',
                    Center_Donation_Type__c = testCenterDonationType.Id
                ));
            }

            // Out of date visits
            Datetime currentDateTime = Datetime.now();
            visits.add(new Visit__c(
                Donor__c = contact.Id,
                Appointment_Datetime__c = currentDateTime.addDays(-366),
                Status__c = 'Complete',
                Outcome__c = 'Donation',
                Center_Donation_Type__c = testCenterDonationType.Id
            ));

            // No Donation visits
            visits.add(new Visit__c(
                Donor__c = contact.Id,
                Appointment_Datetime__c = currentDateTime,
                Status__c = 'Complete',
                Outcome__c = 'Rescheduled',
                Center_Donation_Type__c = testCenterDonationType.Id
            ));
        }
        insert visits;
    }

    @IsTest
    static void successfulBatchRunTest() {
        Test.startTest();
        Database.executeBatch(new DonorBatchable());
        Test.stopTest();

        for(Contact contact : [SELECT Id, Total_Visits_365d__c, Loyalty_Level__r.Name FROM Contact]) {
            Assert.areEqual(EXPECTED_VISIT_PER_CONTACT, contact.Total_Visits_365d__c, 'Each contact should have ' + EXPECTED_VISIT_PER_CONTACT + ' visits in the last 365 days.');
            Assert.areEqual(VIP_LEVEL_NAME, contact.Loyalty_Level__r.Name, 'Each contact should have a loyalty level of ' + VIP_LEVEL_NAME);
        }
    }

    @IsTest 
    static void successScheduleBatchTest() {
        Test.startTest();
        DonorBatchable donorBatchable = new DonorBatchable();
        String runSchedule = '20 30 8 10 2 ?';
        String jobID = System.schedule('Update Donor 365 day Visits', runSchedule, donorBatchable);
        Test.stopTest();
    }
}