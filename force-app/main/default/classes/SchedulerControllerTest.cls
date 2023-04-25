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
            appointment.Datetime__c = DateTime.newInstance(Date.today().year(), Date.today().month(), Date.today().day(), 10, 0, 0);
            appointment.Duration__c = 10;
            appointment.Capacity__c = 5;
            insert appointment;
        }

        System.runAs(TestUtil.createExperienceUser()) {
            List<SchedulerController.AppointmentGroup> appointmentGroups = SchedulerController.getAppointments(center.Id, Date.today());

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
        }

        System.runAs(experienceUser) {
            List<SchedulerController.Visit> visits = SchedulerController.getVisits();

            System.assertEquals(1, visits.size());
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

        System.assertEquals(3, tasks.size()); // Expecting First Visit Code, SPE Exam, and Physcial Exam tasks

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