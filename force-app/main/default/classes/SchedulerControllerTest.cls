@isTest
public with sharing class SchedulerControllerTest {

    @isTest
    static void testGetCenter() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createAdminUser()) {
            Account center = TestUtil.createMiramarCenter();
            insert center;

            AccountContactRelation accountContactRelation = new AccountContactRelation();
            accountContactRelation.AccountId = center.Id;
            accountContactRelation.ContactId = experienceUser.ContactId;
            accountContactRelation.Roles = 'Donor';
            insert accountContactRelation;
        }

        System.runAs(experienceUser) {
            CenterController.Center center = SchedulerController.getCenter();

            System.assertEquals('Proesis Miramar', center.name);
        }
    }

    @isTest
    static void testGetAppointments() {
        Account center;
        Date testDate = DateTime.newInstanceGmt(2100, 1, 1, 0, 0, 0).date();

        System.runAs(TestUtil.createAdminUser()) {
            center = TestUtil.createMiramarCenter();
            insert center;

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = testDate.addDays(-10),
                End_Date__c = testDate.addDays(30)
            );
            insert schedule;

            Appointment__c appointment = new Appointment__c();
            appointment.Schedule__c = schedule.Id;
            appointment.Datetime__c = DateTime.newInstanceGmt(testDate.year(), testDate.month(), testDate.day(), 10, 0, 0);
            appointment.Duration__c = 10;
            appointment.Capacity__c = 5;
            insert appointment;
        }

        System.runAs(TestUtil.createExperienceUser()) {
            List<SchedulerController.AppointmentGroup> appointmentGroups = SchedulerController.getAppointments(center.Id, testDate);

            System.assertEquals(3, appointmentGroups.size());
            System.assertEquals(1, appointmentGroups[0].appointments.size());
            System.assertEquals(0, appointmentGroups[1].appointments.size());
            System.assertEquals(0, appointmentGroups[2].appointments.size());
        }
    }

    @isTest
    static void testGetRescheduleAppointments() {
        User testExperienceUser = TestUtil.createExperienceUser();

        Account center;
        Date testDate = DateTime.newInstanceGmt(2100, 1, 1, 0, 0, 0).date();
        Visit__c createdVisit;

        System.runAs(TestUtil.createAdminUser()) {
            center = TestUtil.createMiramarCenter();
            insert center;

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = testDate.addDays(-10),
                End_Date__c = testDate.addDays(30)
            );
            insert schedule;

            Appointment__c createdAppointment = new Appointment__c();
            createdAppointment.Schedule__c = schedule.Id;
            createdAppointment.Datetime__c = DateTime.newInstanceGmt(testDate.year(), testDate.month(), testDate.day(), 10, 0, 0);
            createdAppointment.Duration__c = 10;
            createdAppointment.Capacity__c = 5;
            insert createdAppointment;

            Center_Donation_Type__c centerDonationType = TestUtil.createCenterDonationType(center.Id);
            insert centerDonationType; 

            // Create a visit for the donor to make sure rescheduleAppointments is recalculating soonestNextVisit
            createdVisit = new Visit__c();
            createdVisit.Appointment__c = createdAppointment.Id;
            createdVisit.Donor__c = testExperienceUser.ContactId;
            createdVisit.Status__c = 'Scheduled';
            createdVisit.Center_Donation_Type__c = centerDonationType.Id;
            insert createdVisit;
        }

        System.runAs(testExperienceUser) {
            List<SchedulerController.AppointmentGroup> appointmentGroups = SchedulerController.getRescheduleAppointments(center.Id, createdVisit.Id, testDate);

            System.assertEquals(3, appointmentGroups.size());
            System.assertEquals(1, appointmentGroups[0].appointments.size());
            System.assertEquals(0, appointmentGroups[1].appointments.size());
            System.assertEquals(0, appointmentGroups[2].appointments.size());
        }
    }

    @isTest
    static void testGetAppointmentsInPast() {
        Account center;
        Date yesterday = Date.today().addDays(-1);

        System.runAs(TestUtil.createAdminUser()) {
            center = TestUtil.createMiramarCenter();
            insert center;

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = Date.today().addDays(-10),
                End_Date__c = Date.today().addDays(30)
            );
            insert schedule;

            Appointment__c appointment = new Appointment__c();
            appointment.Schedule__c = schedule.Id;
            appointment.Datetime__c = DateTime.newInstance(yesterday.year(), yesterday.month(), yesterday.day(), 10, 0, 0);
            appointment.Duration__c = 10;
            appointment.Capacity__c = 5;
            insert appointment;
        }

        System.runAs(TestUtil.createExperienceUser()) {
            List<SchedulerController.AppointmentGroup> appointmentGroups = SchedulerController.getAppointments(center.Id, yesterday);

            System.assertEquals(3, appointmentGroups.size());

            // Appoinments in the past should not be returned.
            System.assertEquals(0, appointmentGroups[0].appointments.size());
            System.assertEquals(0, appointmentGroups[1].appointments.size());
            System.assertEquals(0, appointmentGroups[2].appointments.size());
        }
    }

    @isTest
    static void testGetVisits() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createAdminUser()) {
            Account center = TestUtil.createMiramarCenter();
            insert center;

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = Date.newInstance(2023, 1, 10).addDays(-10),
                End_Date__c = Date.newInstance(2023, 1, 10).addDays(30)
            );
            insert schedule;

            Appointment__c appointment = new Appointment__c();
            appointment.Schedule__c = schedule.Id;
            appointment.Datetime__c = DateTime.newInstance(2023, 1, 10, 10, 0, 0);
            appointment.Duration__c = 10;
            appointment.Capacity__c = 5;
            insert appointment;

            Donation_Type__c donationType = new Donation_Type__c();
            insert donationType;

            Center_Donation_Type__c centerDonationType = new Center_Donation_Type__c();
            centerDonationType.Center__c = center.Id;
            centerDonationType.Donation_Type__c = donationType.Id;
            centerDonationType.isActive__c = true;
            insert centerDonationType;

            Visit__c visit = new Visit__c();
            visit.Appointment__c = appointment.Id;
            visit.Donor__c = experienceUser.ContactId;
            visit.Status__c = 'Scheduled';
            visit.Center_Donation_Type__c = centerDonationType.Id;
            insert visit;

            Transaction__c creditTransactionRecord = new Transaction__c();
            creditTransactionRecord.Visit__c = visit.Id;
            creditTransactionRecord.Donor__c = experienceUser.ContactId;
            creditTransactionRecord.Type__c = 'Credit';
            insert creditTransactionRecord;

            Transaction__c debitTransactionRecord = new Transaction__c();
            debitTransactionRecord.Visit__c = visit.Id;
            debitTransactionRecord.Donor__c = experienceUser.ContactId;
            debitTransactionRecord.Type__c = 'Debit';
            insert debitTransactionRecord;

            List<Txn_Line_Item__c> lineItems = new List<Txn_Line_Item__c> {
                new Txn_Line_Item__c(
                    Transaction__c = creditTransactionRecord.Id,
                    Item__c = 'Donation Points',
                    Quantity__c = 1,
                    Unit_Cost__c = 500,
                    Type__c = 'Points'
                ),
                new Txn_Line_Item__c(
                    Transaction__c = creditTransactionRecord.Id,
                    Item__c = 'Donation Currency',
                    Quantity__c = 1,
                    Unit_Cost__c = 50,
                    Type__c = 'Currency'
                ),
                new Txn_Line_Item__c(
                    Transaction__c = debitTransactionRecord.Id,
                    Item__c = 'Donation Currency',
                    Quantity__c = 1,
                    Unit_Cost__c = 50,
                    Type__c = 'Currency'
                )
            };
            insert lineItems;
        }

        System.runAs(experienceUser) {
            List<SchedulerController.Visit> visits = SchedulerController.getVisits();

            Assert.areEqual(1, visits.size(), 'There should be 1 visit returned.');
            Assert.areEqual(500, visits[0].totalPointReward, 'The donation currency should be 500.');
            Assert.areEqual(50, visits[0].totalCurrencyReward, 'The donation currency should be 50.');
        }
    }

    @isTest
    static void testHasFutureVisitTrue() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createAdminUser()) {
            Account center = TestUtil.createMiramarCenter();
            insert center;

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = Date.today().addDays(-10),
                End_Date__c = Date.today().addDays(30)
            );
            insert schedule;

            Appointment__c appointment = new Appointment__c();
            appointment.Schedule__c = schedule.Id;
            appointment.Datetime__c = DateTime.now().addDays(1);
            appointment.Duration__c = 10;
            appointment.Capacity__c = 5;
            insert appointment;

            Donation_Type__c donationType = new Donation_Type__c();
            insert donationType;

            Center_Donation_Type__c centerDonationType = new Center_Donation_Type__c();
            centerDonationType.Center__c = center.Id;
            centerDonationType.Donation_Type__c = donationType.Id;
            centerDonationType.isActive__c = true;
            insert centerDonationType;

            Visit__c visit = new Visit__c();
            visit.Appointment__c = appointment.Id;
            visit.Donor__c = experienceUser.ContactId;
            visit.Status__c = 'Scheduled';
            visit.Center_Donation_Type__c = centerDonationType.Id;
            insert visit;
        }

        System.runAs(experienceUser) {
            Boolean hasFutureVisit = SchedulerController.hasFutureVisit();

            System.assertEquals(true, hasFutureVisit);
        }
    }

    @isTest
    static void testHasFutureVisitFalse() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createAdminUser()) {
            Account center = TestUtil.createMiramarCenter();
            insert center;

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = Date.today().addDays(-10),
                End_Date__c = Date.today().addDays(30)
            );
            insert schedule;

            Appointment__c appointment = new Appointment__c();
            appointment.Schedule__c = schedule.Id;
            appointment.Datetime__c = DateTime.now().addDays(-1);
            appointment.Duration__c = 10;
            appointment.Capacity__c = 5;
            insert appointment;

            Donation_Type__c donationType = new Donation_Type__c();
            insert donationType;

            Center_Donation_Type__c centerDonationType = new Center_Donation_Type__c();
            centerDonationType.Center__c = center.Id;
            centerDonationType.Donation_Type__c = donationType.Id;
            centerDonationType.isActive__c = true;
            insert centerDonationType;

            Visit__c visit = new Visit__c();
            visit.Appointment__c = appointment.Id;
            visit.Donor__c = experienceUser.ContactId;
            visit.Status__c = 'Scheduled';
            visit.Center_Donation_Type__c = centerDonationType.Id;
            insert visit;
        }

        System.runAs(experienceUser) {
            Boolean hasFutureVisit = SchedulerController.hasFutureVisit();

            System.assertEquals(false, hasFutureVisit);
        }
    }

    @isTest
    static void testHasFutureVisitException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceUser()) {
            Boolean exceptionThrown = false;

            try {
                SchedulerController.hasFutureVisit();
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testScheduleVisit() {
        Appointment__c appointment;

        System.runAs(TestUtil.createAdminUser()) {
            Account center = TestUtil.createMiramarCenter();
            insert center;

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = Date.newInstance(2023, 1, 10).addDays(-10),
                End_Date__c = Date.newInstance(2023, 1, 10).addDays(30)
            );
            insert schedule;

            appointment = new Appointment__c();
            appointment.Schedule__c = schedule.Id;
            appointment.Datetime__c = DateTime.newInstance(2023, 1, 10, 10, 0, 0);
            appointment.Duration__c = 10;
            appointment.Capacity__c = 5;
            insert appointment;

            Donation_Type__c donationType = new Donation_Type__c();
            insert donationType;

            Center_Donation_Type__c centerDonationType = new Center_Donation_Type__c();
            centerDonationType.Center__c = center.Id;
            centerDonationType.Donation_Type__c = donationType.Id;
            centerDonationType.isActive__c = true;
            insert centerDonationType;
        }

        System.runAs(TestUtil.createExperienceUser()) {
            Id visitId = SchedulerController.scheduleVisit(appointment.Id);
        }

        List<Task> tasks = [SELECT Subject, Description FROM Task];

        // Expecting First Visit Code, SPE Exam, and Physical Exam tasks
        // As of 5/26/23, the SPE and Physical Exam tasks are no longer created
        System.assertEquals(1, tasks.size()); 

        Set<String> expectedTasks = new Set<String>{Constants.SPE_ANALYSIS_TASK_SUBJECT, Constants.PHYSICAL_EXAM_TASK_SUBJECT, Constants.FIRST_VISIT_CODE_TASK_SUBJECT};

        for (Task task : tasks) {
            Assert.isTrue(expectedTasks.contains(task.Subject));
            expectedTasks.remove(task.Subject);

            if (task.Subject == Constants.FIRST_VISIT_CODE_TASK_SUBJECT) {
                System.assertEquals(7, task.Description.length(), 'First Visit Code should be 7 characters long');
            }
        }

        Appointment__c targetAppointment = [SELECT Booked__c FROM Appointment__c WHERE Id = :appointment.Id];

        System.assertEquals(1, targetAppointment.Booked__c, 'Adding a visit should increment the booked value');
    }

    @isTest
    static void testRescheduleVisit() {
        User experienceUser = TestUtil.createExperienceUser();

        List<Appointment__c> testAppointments;
        Visit__c testVisit;

        System.runAs(TestUtil.createAdminUser()) {
            Account center = TestUtil.createMiramarCenter();
            insert center;

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = Date.newInstance(2023, 1, 10).addDays(-10),
                End_Date__c = Date.newInstance(2023, 1, 10).addDays(30)
            );
            insert schedule;

            testAppointments = new List<Appointment__c> {
                new Appointment__c(
                    Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(2023, 1, 10, 10, 0, 0),
                    Duration__c = 10,
                    Capacity__c = 5
                ),
                new Appointment__c(
                    Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(2023, 1, 10, 11, 0, 0),
                    Duration__c = 10,
                    Capacity__c = 5
                )
            };
            insert testAppointments;

            Donation_Type__c donationType = new Donation_Type__c();
            insert donationType;

            Center_Donation_Type__c centerDonationType = new Center_Donation_Type__c();
            centerDonationType.Center__c = center.Id;
            centerDonationType.Donation_Type__c = donationType.Id;
            centerDonationType.isActive__c = true;
            insert centerDonationType;

            testVisit = new Visit__c();
            testVisit.Appointment__c = testAppointments[0].Id;
            testVisit.Donor__c = experienceUser.ContactId;
            testVisit.Status__c = 'Scheduled';
            testVisit.Center_Donation_Type__c = centerDonationType.Id;
            insert testVisit;

            Test.startTest();
            SchedulerController.rescheduleVisit(testAppointments[1].Id, testVisit.Id);
            Test.stopTest();
        }

        Visit__c originalVisit = [SELECT Id, Status__c, Outcome__c, Appointment__c FROM Visit__c WHERE Id = :testVisit.Id LIMIT 1];
        Assert.areEqual('Complete', originalVisit.Status__c, 'Original visit should be marked as complete');
        Assert.areEqual('Rescheduled', originalVisit.Outcome__c, 'Original visit should be marked as rescheduled');

        Visit__c newVisit = [SELECT Id, Status__c, Outcome__c, Appointment__c FROM Visit__c WHERE Id != :testVisit.Id LIMIT 1];
        Assert.areEqual('Scheduled', newVisit.Status__c, 'New visit should be marked as scheduled');
        Assert.isNull(newVisit.Outcome__c, 'New visit should not have an outcome');
        Assert.areEqual(testAppointments[1].Id, newVisit.Appointment__c, 'New visit should be associated with the new appointment');
    }

    @isTest
    static void testCancelVisit() {
        User experienceUser = TestUtil.createExperienceUser();

        List<Appointment__c> testAppointments;
        Visit__c testVisit;

        System.runAs(TestUtil.createAdminUser()) {
            Account center = TestUtil.createMiramarCenter();
            insert center;

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = Date.newInstance(2023, 1, 10).addDays(-10),
                End_Date__c = Date.newInstance(2023, 1, 10).addDays(30)
            );
            insert schedule;

            testAppointments = new List<Appointment__c> {
                new Appointment__c(
                    Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(2023, 1, 10, 10, 0, 0),
                    Duration__c = 10,
                    Capacity__c = 5
                )
            };
            insert testAppointments;

            Donation_Type__c donationType = new Donation_Type__c();
            insert donationType;

            Center_Donation_Type__c centerDonationType = new Center_Donation_Type__c();
            centerDonationType.Center__c = center.Id;
            centerDonationType.Donation_Type__c = donationType.Id;
            centerDonationType.isActive__c = true;
            insert centerDonationType;

            testVisit = new Visit__c();
            testVisit.Appointment__c = testAppointments[0].Id;
            testVisit.Donor__c = experienceUser.ContactId;
            testVisit.Status__c = 'Scheduled';
            testVisit.Center_Donation_Type__c = centerDonationType.Id;
            insert testVisit;

            Test.startTest();
            SchedulerController.cancelVisit(testVisit.Id);
            Test.stopTest();
        }

        Visit__c cancelledVisit = [SELECT Id, Status__c, Outcome__c FROM Visit__c WHERE Id = :testVisit.Id LIMIT 1];
        Assert.areEqual('Complete', cancelledVisit.Status__c, 'Original visit should be marked as complete');
        Assert.areEqual('Canceled', cancelledVisit.Outcome__c, 'Original visit should be marked as canceled');
    }
}