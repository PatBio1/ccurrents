@IsTest
public class VisitTriggerHandlerTest {
    static final Integer AMOUNT_OF_VISITS = 99;

    @TestSetup
    static void makeTestData() {
        List<Account> testCenters = new List<Account> {
            TestUtil.createMiramarCenter()
        };
        insert testCenters;

        Center_Donation_Type__c donationType = TestUtil.createCenterDonationType(testCenters[0].Id);
        insert donationType;

        List<Account> testDonors = new List<Account>();
        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            testDonors.add(TestUtil.createTestDonor(ScheduleUtils.createFirstVisitCode()));
        }
        insert testDonors;

        List<Business_Hours__c> businessHours = TestUtil.createBusinessHours(testCenters[0].Id);
        insert businessHours;

        Date startDate = Date.today();
        Date endDate = Date.today().addMonths(1);

        Schedule__c schedule = ScheduleUtils.createScheduleRecord(testCenters[0].Id, startDate, endDate);
        insert schedule;

        insert new Appointment__c(
            Schedule__c = schedule.Id,
            Datetime__c = Datetime.now().addDays(3),
            Capacity__c = AMOUNT_OF_VISITS
        );
    }

    @IsTest static void updateAppointmentDateTimeInsertSuccess() {
        Appointment__c targetAppointment = [SELECT Id, Datetime__c FROM Appointment__c LIMIT 1];
        Center_Donation_Type__c donationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        List<Account> targetDonors = [SELECT Id, PersonContactId FROM Account WHERE DonorId__c != NULL];
        List<Visit__c> testVisits = new List<Visit__c>();

        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            testVisits.add(new Visit__c(
                Center_Donation_Type__c = donationType.Id,
                Donor__c = targetDonors[i].PersonContactId,
                Appointment__c = targetAppointment.Id,
                Status__c = 'Scheduled'
            ));
        }

        Test.startTest();
        insert testVisits;
        Test.stopTest();

        for(Visit__c testVisit : [SELECT Id, Appointment_Datetime__c FROM Visit__c WHERE Id IN :testVisits]) {
            Assert.areEqual(targetAppointment.Datetime__c, testVisit.Appointment_Datetime__c, 'The Appointment Datetime on the visit wasn\'t synced with the appointment Datetime');
        }
    }

    @IsTest static void updateAppointmentDateTimeUpdateSuccess() {
        Appointment__c targetAppointment = [SELECT Id, Datetime__c FROM Appointment__c LIMIT 1];
        Center_Donation_Type__c donationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        List<Account> targetDonors = [SELECT Id, PersonContactId FROM Account WHERE DonorId__c != NULL];
        List<Visit__c> testVisits = new List<Visit__c>();

        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            testVisits.add(new Visit__c(
                Center_Donation_Type__c = donationType.Id,
                Donor__c = targetDonors[i].PersonContactId,
                Status__c = 'Scheduled'
            ));
        }
        insert testVisits;

        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            testVisits[i].Appointment__c = targetAppointment.Id;
        }

        Test.startTest();
        update testVisits;
        Test.stopTest();

        for(Visit__c testVisit : [SELECT Id, Appointment_Datetime__c FROM Visit__c WHERE Id IN :testVisits]) {
            Assert.areEqual(targetAppointment.Datetime__c, testVisit.Appointment_Datetime__c, 'The Appointment Datetime on the visit wasn\'t synced with the appointment Datetime');
        }
    }
}