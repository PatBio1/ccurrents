@isTest
public with sharing class SchedulerControllerTest {

    @TestSetup
    static void setupData() {
        TestUtil.createAdminUser();
    }

    @isTest
    static void testGetCenter() {
        User experienceUser = TestUtil.createExperienceUser();
        User adminUser = [SELECT Id FROM User WHERE Name = 'Admin User'];

        System.runAs(adminUser) {
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

        User adminUser = [SELECT Id FROM User WHERE Name = 'Admin User'];

        System.runAs(adminUser) {
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

        User adminUser = [SELECT Id FROM User WHERE Name = 'Admin User'];

        Date yesterday = Date.today().addDays(-1);

        System.runAs(adminUser) {
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
        User adminUser = [SELECT Id FROM User WHERE Name = 'Admin User'];

        System.runAs(adminUser) {
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

        User adminUser = [SELECT Id FROM User WHERE Name = 'Admin User'];

        System.runAs(adminUser) {
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

}