@isTest
public with sharing class SchedulerControllerTest {
    @TestSetup
    static void makeData(){
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
        User experienceUser = TestUtil.createExperienceUser();
        User adminUser = [SELECT Id FROM User WHERE Name = 'Admin User'];
        System.runAs(adminUser) {
            center = TestUtil.createMiramarCenter();
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
        }

        System.runAs(experienceUser) {
            SchedulerController.AppointmentGroups appointmentGroups = SchedulerController.getAppointments(center.Id, Date.newInstance(2023, 1, 10));

            System.assertEquals(1, appointmentGroups.morningAppointments.size());
            System.assertEquals(0, appointmentGroups.afternoonAppointments.size());
            System.assertEquals(0, appointmentGroups.eveningAppointments.size());
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
        User experienceUser = TestUtil.createExperienceUser();

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

        System.runAs(experienceUser) {
            Id visitId = SchedulerController.scheduleVisit(appointment.Id);   
        }
        Task[] tasks = [SELECT ID, Subject, Description  FROM Task];
        system.assertEquals(1, tasks.size());
        system.assertEquals('First Visit Code', tasks[0].Subject);
        system.assertEquals(7, tasks[0].Description.length());
    }

}