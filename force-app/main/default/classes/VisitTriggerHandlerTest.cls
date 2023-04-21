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
        Date endDate = Date.today().addYears(2);

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
            ),
            new Appointment__c(
                Schedule__c = schedule.Id,
                Datetime__c = Datetime.now().addDays(3).addYears(1),
                Capacity__c = AMOUNT_OF_VISITS
            ),
            new Appointment__c(
                Schedule__c = schedule.Id,
                Datetime__c = Datetime.now().addDays(3).addYears(2),
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

        for(Visit__c testVisit : [SELECT Id, isFirstVisit__c, Physical_Exam__c, SPE_Analysis__c FROM Visit__c WHERE Id IN :testVisits]) {
            Assert.isTrue(testVisit.isFirstVisit__c, 'The Is First Visit flag on the visit wasn\'t set to true');
            Assert.isTrue(testVisit.Physical_Exam__c, 'The Is Physical Exam flag on the visit wasn\'t set to true');
            Assert.isTrue(testVisit.SPE_Analysis__c, 'The Is SPE Analysis flag on the visit wasn\'t set to true');
        }
    }

    @isTest static void testSetSecondIsFirstVisitFlag() {
        List<Appointment__c> targetAppointments = [SELECT Id, Datetime__c FROM Appointment__c ORDER BY Datetime__c DESC LIMIT 2];
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

        for(Visit__c firstVisit : [SELECT Id, isFirstVisit__c, Physical_Exam__c, SPE_Analysis__c FROM Visit__c WHERE Id IN :testVisits]) {
            Assert.isTrue(firstVisit.isFirstVisit__c, 'The Is First Visit flag on the visit wasn\'t set to true');
            Assert.isTrue(firstVisit.Physical_Exam__c, 'The Is Physical Exam flag on the visit wasn\'t set to true');
            Assert.isTrue(firstVisit.SPE_Analysis__c, 'The Is SPE Analysis flag on the visit wasn\'t set to true');
        }

        List<Visit__c> testSecondVisits = new List<Visit__c>();
        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            testSecondVisits.add(new Visit__c(
                Center_Donation_Type__c = donationType.Id,
                Donor__c = targetDonors[i].PersonContactId,
                Appointment__c = targetAppointments[1].Id,
                Status__c = 'Scheduled'
            ));
        }

        Test.startTest();
        insert testSecondVisits;
        Test.stopTest();

        for(Visit__c firstVisit : [SELECT Id, isFirstVisit__c, Physical_Exam__c, SPE_Analysis__c FROM Visit__c WHERE Id IN :testVisits]) {
            Assert.isFalse(firstVisit.isFirstVisit__c, 'The Is First Visit flag on the visit wasn\'t set to false');
            Assert.isFalse(firstVisit.Physical_Exam__c, 'The Is Physical Exam flag on the visit wasn\'t set to false');
            Assert.isFalse(firstVisit.SPE_Analysis__c, 'The Is SPE Analysis flag on the visit wasn\'t set to false');
        }

        for(Visit__c secondVisit : [SELECT Id, isFirstVisit__c, Physical_Exam__c, SPE_Analysis__c FROM Visit__c WHERE Id IN :testSecondVisits]) {
            Assert.isTrue(secondVisit.isFirstVisit__c, 'The Is First Visit flag on the visit wasn\'t set to true');
            Assert.isTrue(secondVisit.Physical_Exam__c, 'The Is Physical Exam flag on the visit wasn\'t set to true');
            Assert.isTrue(secondVisit.SPE_Analysis__c, 'The Is SPE Analysis flag on the visit wasn\'t set to true');
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

        for(Visit__c testVisit : [SELECT Id, isFirstVisit__c, SPE_Analysis__c, Physical_Exam__c FROM Visit__c WHERE Id IN :secondSetOfVisits]) {
            Assert.isFalse(testVisit.isFirstVisit__c, 'The First Visit Flag shouldn\'t have been set to true');
            Assert.isFalse(testVisit.Physical_Exam__c, 'The Physical Exam Flag shouldn\'t have been set to true');
            Assert.isFalse(testVisit.SPE_Analysis__c, 'The SPE Analysis Flag shouldn\'t have been set to true');
        }
    }

    @isTest static void testAnnualExamAndSPETasks() {
        // Create an inital appointment for each donor to set the Days_Until... fields
        Appointment__c targetAppointment = [SELECT Id, Datetime__c FROM Appointment__c ORDER BY Datetime__c ASC LIMIT 1];
        Center_Donation_Type__c donationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        List<Account> targetDonors = [SELECT Id, PersonContactId FROM Account WHERE DonorId__c != NULL];
        List<Visit__c> testVisits = new List<Visit__c>();

        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            testVisits.add(new Visit__c(
                Center_Donation_Type__c = donationType.Id,
                Donor__c = targetDonors[i].PersonContactId,
                Appointment__c = targetAppointment.Id,
                Status__c = 'Complete',
                Outcome__c = 'Donation'
            ));
        }
        insert testVisits;

        // Create the appointment that actually triggers the Annual Exam / SPE Analysis tasks
        List<Account> donorsWithAnnualExamDates = [SELECT Id, Days_Until_Annum__pc, Days_until_Triannum__pc FROM Account WHERE Id IN :targetDonors];
        DateTime targetDateTime = Datetime.now().date().addDays((Integer)Math.max(donorsWithAnnualExamDates[0].Days_Until_Annum__pc, donorsWithAnnualExamDates[0].Days_until_Triannum__pc));

        Appointment__c annualExamsAppointment = [
            SELECT Id, Datetime__c 
            FROM Appointment__c 
            WHERE Datetime__c >= :targetDateTime
            LIMIT 1
        ];

        List<Visit__c> annualExams = new List<Visit__c>();
        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            annualExams.add(new Visit__c(
                Center_Donation_Type__c = donationType.Id,
                Donor__c = targetDonors[i].PersonContactId,
                Appointment__c = annualExamsAppointment.Id,
                Status__c = 'Scheduled'
            ));
        }

        Test.startTest();
        insert annualExams;
        Test.stopTest();

        // Check to make sure two tasks where created for each annual exam
        for(Visit__c annualExamVisit : [SELECT Id, (SELECT Id, Subject FROM Tasks) FROM Visit__c WHERE Id IN :annualExams]) {
            Set<String> expectedTasks = new Set<String>{ Constants.SPE_ANALYSIS_TASK_SUBJECT, Constants.PHYSICAL_EXAM_TASK_SUBJECT };
            Assert.areEqual(expectedTasks.size(), annualExamVisit.Tasks.size(), 'There should be ' + expectedTasks.size() + ' tasks created for each annual exam visit');

            for(Task annualExamVisitTask : annualExamVisit.Tasks) {
                Assert.isTrue(expectedTasks.contains(annualExamVisitTask.Subject), 'The task subject was not one of the expected values');
                expectedTasks.remove(annualExamVisitTask.Subject);
            }
        }
    }

    @isTest static void testRescheuleAnnualExamAndSPETasks() {
        // Create an inital appointment for each donor to set the Days_Until... fields
        Appointment__c targetAppointment = [SELECT Id, Datetime__c FROM Appointment__c ORDER BY Datetime__c ASC LIMIT 1];
        Center_Donation_Type__c donationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        List<Account> targetDonors = [SELECT Id, PersonContactId FROM Account WHERE DonorId__c != NULL];
        List<Visit__c> testVisits = new List<Visit__c>();

        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            testVisits.add(new Visit__c(
                Center_Donation_Type__c = donationType.Id,
                Donor__c = targetDonors[i].PersonContactId,
                Appointment__c = targetAppointment.Id,
                Status__c = 'Complete',
                Outcome__c = 'Donation'
            ));
        }
        insert testVisits;

        // Create the appointment that actually triggers the Annual Exam / SPE Analysis tasks
        List<Account> donorsWithAnnualExamDates = [SELECT Id, Days_Until_Annum__pc, Days_until_Triannum__pc FROM Account WHERE Id IN :targetDonors];
        DateTime targetDateTime = Datetime.now().date().addDays((Integer)Math.max(donorsWithAnnualExamDates[0].Days_Until_Annum__pc, donorsWithAnnualExamDates[0].Days_until_Triannum__pc));

        List<Appointment__c> annualExamsAppointments = [
            SELECT Id, Datetime__c 
            FROM Appointment__c 
            WHERE Datetime__c >= :targetDateTime
            ORDER BY DateTime__c DESC
            LIMIT 2
        ];

        List<Visit__c> annualExams = new List<Visit__c>();
        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            annualExams.add(new Visit__c(
                Center_Donation_Type__c = donationType.Id,
                Donor__c = targetDonors[i].PersonContactId,
                Appointment__c = annualExamsAppointments[0].Id, // Using the first index ensures we use the furthest out appointment, allowing an earlier reschedule
                Status__c = 'Scheduled'
            ));
        }
        insert annualExams;

        // Check to make sure the tasks were created in the first place
        for(Visit__c annualExamVisit : [SELECT Id, (SELECT Id, Subject FROM Tasks) FROM Visit__c WHERE Id IN :annualExams]) {
            Set<String> expectedTasks = new Set<String>{ Constants.SPE_ANALYSIS_TASK_SUBJECT, Constants.PHYSICAL_EXAM_TASK_SUBJECT };
            Assert.areEqual(expectedTasks.size(), annualExamVisit.Tasks.size(), 'There should be ' + expectedTasks.size() + ' tasks created for each annual exam visit');

            for(Task annualExamVisitTask : annualExamVisit.Tasks) {
                Assert.isTrue(expectedTasks.contains(annualExamVisitTask.Subject), 'The task subject was not one of the expected values');
                expectedTasks.remove(annualExamVisitTask.Subject);
            }
        }

        // Reschedule the annual exams to the second appointment
        List<Visit__c> rescheduledAnnualExams = new List<Visit__c>();
        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            rescheduledAnnualExams.add(new Visit__c(
                Center_Donation_Type__c = donationType.Id,
                Donor__c = targetDonors[i].PersonContactId,
                Appointment__c = annualExamsAppointments[1].Id, // Using the second index ensures we use the closest appointment, this should trigger the reparenting of the tasks
                Status__c = 'Scheduled'
            ));
        }

        Test.startTest();
        insert rescheduledAnnualExams;
        Test.stopTest();

        // Check to make sure the initial tasks are now not related to the first visits
        for(Visit__c annualExamVisit : [SELECT Id, (SELECT Id, Subject FROM Tasks) FROM Visit__c WHERE Id IN :annualExams]) {
            Assert.areEqual(0, annualExamVisit.Tasks.size(), 'There should be no tasks related to the initial annual exam visits');
        }

        // Check to make sure two tasks where created for each annual exam
        for(Visit__c annualExamVisit : [SELECT Id, (SELECT Id, Subject FROM Tasks) FROM Visit__c WHERE Id IN :rescheduledAnnualExams]) {
            Set<String> expectedTasks = new Set<String>{ Constants.SPE_ANALYSIS_TASK_SUBJECT, Constants.PHYSICAL_EXAM_TASK_SUBJECT };
            Assert.areEqual(expectedTasks.size(), annualExamVisit.Tasks.size(), 'There should be ' + expectedTasks.size() + ' tasks created for each annual exam visit');

            for(Task annualExamVisitTask : annualExamVisit.Tasks) {
                Assert.isTrue(expectedTasks.contains(annualExamVisitTask.Subject), 'The task subject was not one of the expected values');
                expectedTasks.remove(annualExamVisitTask.Subject);
            }
        }
    }

    @isTest static void testUpdateLastPreviousDonation() {
        List<Appointment__c> targetAppointments = [SELECT Id, Datetime__c FROM Appointment__c ORDER BY Datetime__c DESC LIMIT 2];
        Center_Donation_Type__c donationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        List<Account> targetDonors = [SELECT Id, PersonContactId FROM Account WHERE DonorId__c != NULL];
        List<Visit__c> testVisits = new List<Visit__c>();

        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            testVisits.add(new Visit__c(
                Center_Donation_Type__c = donationType.Id,
                Donor__c = targetDonors[i].PersonContactId,
                Appointment__c = targetAppointments[0].Id,
                Status__c = 'Complete',
                Outcome__c = 'Donation'
            ));
        }
        insert testVisits;

        List<Visit__c> lastPreviousDonationVisits = new List<Visit__c>();
        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            lastPreviousDonationVisits.add(new Visit__c(
                Center_Donation_Type__c = donationType.Id,
                Donor__c = targetDonors[i].PersonContactId,
                Appointment__c = targetAppointments[1].Id,
                Status__c = 'Complete',
                Outcome__c = 'Donation'
            ));
        }

        Test.startTest();
        insert lastPreviousDonationVisits;
        Test.stopTest();

        // Check to make sure the last previous donation was updated on the visit's donor
        for(Visit__c lastPreviousDonationVisit : [SELECT Id, Donor__c, Donor__r.Last_Previous_Donation__c FROM Visit__c WHERE Id IN :lastPreviousDonationVisits]) {
            Assert.areEqual(lastPreviousDonationVisit.Id, lastPreviousDonationVisit.Donor__r.Last_Previous_Donation__c, 'The donor\'s last previous donation was not updated');
        }
    }

    @isTest static void testNoUpdateLastPreviousDonation() {
        List<Appointment__c> targetAppointments = [SELECT Id, Datetime__c FROM Appointment__c ORDER BY Datetime__c DESC LIMIT 2];
        Center_Donation_Type__c donationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        List<Account> targetDonors = [SELECT Id, PersonContactId FROM Account WHERE DonorId__c != NULL];
        List<Visit__c> testVisits = new List<Visit__c>();

        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            testVisits.add(new Visit__c(
                Center_Donation_Type__c = donationType.Id,
                Donor__c = targetDonors[i].PersonContactId,
                Appointment__c = targetAppointments[0].Id,
                Status__c = 'Complete',
                Outcome__c = 'Donation'
            ));
        }

        Test.startTest();
        insert testVisits;
        Test.stopTest();

        // Check to make sure Last Previous donation was not updated on the visit's donor
        for(Visit__c testVisit : [SELECT Id, Donor__c, Donor__r.Last_Previous_Donation__c FROM Visit__c WHERE Id IN :testVisits]) {
            Assert.isNull(testVisit.Donor__r.Last_Previous_Donation__c, 'The donor\'s last previous donation was updated');
        }
    }

    @isTest static void testUpdateLastPreviousScheduledVisit() {
        List<Appointment__c> targetAppointments = [SELECT Id, Datetime__c FROM Appointment__c ORDER BY Datetime__c DESC LIMIT 2];
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

        List<Visit__c> lastPreviousScheduledVisits = new List<Visit__c>();
        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            lastPreviousScheduledVisits.add(new Visit__c(
                Center_Donation_Type__c = donationType.Id,
                Donor__c = targetDonors[i].PersonContactId,
                Appointment__c = targetAppointments[1].Id,
                Status__c = 'Checked-In'
            ));
        }

        Test.startTest();
        insert lastPreviousScheduledVisits;
        Test.stopTest();

        // Check to make sure the last previous donation was updated on the visit's donor
        for(Visit__c lastPreviousScheduledVisit : [SELECT Id, Donor__c, Donor__r.Last_Previous_Scheduled_Visit__c FROM Visit__c WHERE Id IN :lastPreviousScheduledVisits]) {
            Assert.areEqual(lastPreviousScheduledVisit.Id, lastPreviousScheduledVisit.Donor__r.Last_Previous_Scheduled_Visit__c, 'The donor\'s last previous scheduled visit was not updated');
        }
    }

    @isTest static void testUpdateLastPreviousScheduledVisitToNull() {
        List<Appointment__c> targetAppointments = [SELECT Id, Datetime__c FROM Appointment__c ORDER BY Datetime__c DESC LIMIT 2];
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

        List<Visit__c> lastPreviousScheduledVisits = new List<Visit__c>();
        for(Integer i = 0; i < AMOUNT_OF_VISITS; i++) {
            lastPreviousScheduledVisits.add(new Visit__c(
                Center_Donation_Type__c = donationType.Id,
                Donor__c = targetDonors[i].PersonContactId,
                Appointment__c = targetAppointments[1].Id,
                Status__c = 'Checked-In'
            ));
        }
        insert lastPreviousScheduledVisits;

        // Check to make sure the last previous donation was updated on the visit's donor
        for(Visit__c lastPreviousScheduledVisit : [SELECT Id, Donor__c, Donor__r.Last_Previous_Scheduled_Visit__c FROM Visit__c WHERE Id IN :lastPreviousScheduledVisits]) {
            Assert.areEqual(lastPreviousScheduledVisit.Id, lastPreviousScheduledVisit.Donor__r.Last_Previous_Scheduled_Visit__c, 'The donor\'s last previous scheduled visit was not updated');
        }

        // Canceled visits shouldn't be stored in the last previous scheduled visit field
        // This should cause the field to be set to null
        for(Visit__c lastPreviousScheduledVisit : lastPreviousScheduledVisits) {
            lastPreviousScheduledVisit.Status__c = 'Complete';
            lastPreviousScheduledVisit.Outcome__c = 'Canceled';
        }

        Test.startTest();
        update lastPreviousScheduledVisits;
        Test.stopTest();

        // Check to make sure the last previous donation was updated on the visit's donor
        for(Visit__c lastPreviousScheduledVisit : [SELECT Id, Donor__c, Donor__r.Last_Previous_Scheduled_Visit__c FROM Visit__c WHERE Id IN :lastPreviousScheduledVisits]) {
            Assert.isNull(lastPreviousScheduledVisit.Donor__r.Last_Previous_Scheduled_Visit__c, 'The donor\'s last previous scheduled visit was not cleared after canceling the visit');
        }
    }

    @isTest static void testNoUpdateLastPreviousScheduledVisit() {
        List<Appointment__c> targetAppointments = [SELECT Id, Datetime__c FROM Appointment__c ORDER BY Datetime__c DESC LIMIT 2];
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

        Test.startTest();
        insert testVisits;
        Test.stopTest();

        // Check to make sure Last Previous donation was not updated on the visit's donor
        for(Visit__c testVisit : [SELECT Id, Donor__c, Donor__r.Last_Previous_Scheduled_Visit__c FROM Visit__c WHERE Id IN :testVisits]) {
            Assert.isNull(testVisit.Donor__r.Last_Previous_Scheduled_Visit__c, 'The donor\'s last previous scheduled visit was updated');
        }
    }
}