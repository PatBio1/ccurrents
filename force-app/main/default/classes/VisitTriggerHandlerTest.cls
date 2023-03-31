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

        insert new List<Appointment__c> {
            new Appointment__c(
                Schedule__c = schedule.Id,
                Datetime__c = Datetime.now().addDays(3),
                Capacity__c = AMOUNT_OF_VISITS
            ),
            new Appointment__c(
                Schedule__c = schedule.Id,
                Datetime__c = Datetime.now().addDays(4),
                Capacity__c = AMOUNT_OF_VISITS
            )
        };
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

    @isTest static void testUpdateDonorDates() {
        Appointment__c targetAppointment = [SELECT Id, Datetime__c FROM Appointment__c LIMIT 1];
        Center_Donation_Type__c donationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        List<Account> targetDonors = [SELECT Id, PersonContactId FROM Account WHERE DonorId__c != NULL];
        List<Visit__c> testVisits = new List<Visit__c>();

        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            testVisits.add(new Visit__c(
                Center_Donation_Type__c = donationType.Id,
                Donor__c = targetDonors[i].PersonContactId,
                Appointment__c = targetAppointment.Id,
                Status__c = 'Scheduled',
                Physical_Exam__c = true,
                SPE_Analysis__c = true
            ));
        }

        Test.startTest();
        insert testVisits;
        Test.stopTest();

        for(Contact targetDonor : [SELECT Id, Last_Physical_Exam_Date__c, Last_SPE_Sample_Date__c FROM Contact WHERE Id IN (SELECT PersonContactId FROM Account WHERE Id IN :targetDonors)]) {
            Assert.areEqual(targetAppointment.Datetime__c.date(), targetDonor.Last_Physical_Exam_Date__c, 'The Last Physical Exam Date on the donor wasn\'t synced with the appointment Datetime');
            Assert.areEqual(targetAppointment.Datetime__c.date(), targetDonor.Last_SPE_Sample_Date__c, 'The Last SPE Sample Date on the donor wasn\'t synced with the appointment Datetime');
        }
    }

    @isTest static void testSetIsFirstVisitFlag() {
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

        for(Visit__c testVisit : [SELECT Id, isFirstVisit__c FROM Visit__c WHERE Id IN :testVisits]) {
            Assert.isTrue(testVisit.isFirstVisit__c, 'The Is First Visit flag on the visit wasn\'t set to true');
        }
    }

    @isTest static void testNotSetIsFirstFlag() {
        List<Appointment__c> targetAppointments = [SELECT Id, Datetime__c FROM Appointment__c LIMIT 2];
        Center_Donation_Type__c donationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        List<Account> targetDonors = [SELECT Id, PersonContactId FROM Account WHERE DonorId__c != NULL];
        List<Visit__c> testVisits = new List<Visit__c>();

        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            testVisits.add(new Visit__c(
                Center_Donation_Type__c = donationType.Id,
                Donor__c = targetDonors[i].PersonContactId,
                Appointment__c = targetAppointments[0].Id,
                Status__c = 'Scheduled'
            ));
        }
        insert testVisits;

        List<Visit__c> secondSetOfVisits = new List<Visit__c>();
        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            secondSetOfVisits.add(new Visit__c(
                Center_Donation_Type__c = donationType.Id,
                Donor__c = targetDonors[i].PersonContactId,
                Appointment__c = targetAppointments[1].Id,
                Status__c = 'Scheduled'
            ));
        }

        Test.startTest();
        insert secondSetOfVisits;
        Test.stopTest();

        for(Visit__c testVisit : [SELECT Id, isFirstVisit__c FROM Visit__c WHERE Id IN :secondSetOfVisits]) {
            Assert.isFalse(testVisit.isFirstVisit__c, 'The First Visit Flag shouldn\'t have been set to true');
        }
    }
}