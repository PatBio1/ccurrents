@isTest
public with sharing class SchedulerControllerTest {

    @isTest
    static void testUpsertLead() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            SchedulerController.Profile profile = new SchedulerController.Profile();
            profile.firstName = 'First';
            profile.middleName = 'Middle';
            profile.lastName = 'Last';

            Id leadId = SchedulerController.upsertLead(profile);

            Lead lead = [
                SELECT
                    FirstName, MiddleName, LastName
                FROM
                    Lead
                WHERE
                    Id = :leadId
            ];

            System.assertEquals('First', lead.FirstName);
            System.assertEquals('Middle', lead.MiddleName);
            System.assertEquals('Last', lead.LastName);
        }
    }

    @isTest
    static void testCreateUser() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            Account account = new Account();
            account.Name = 'Center';
            account.RecordTypeID = Constants.CENTER_RECORD_TYPE_ID;
            insert account;

            Lead lead = new Lead();
            lead.FirstName = 'First';
            lead.LastName = 'Last';
            insert lead;

            SchedulerController.Profile profile = new SchedulerController.Profile();
            profile.id = lead.Id;
            profile.centerId = account.Id;

            Id userId = SchedulerController.createUser(profile);

            User user = [
                SELECT
                    FirstName, LastName
                FROM
                    User
                WHERE
                    Name = 'First Last'
            ];

            System.assertEquals('First', user.FirstName);
            System.assertEquals('Last', user.LastName);
        }
    }

    @isTest
    static void testAssignPermissionSet() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createExperienceGuestUser()) {
            SchedulerController.assignPermissionSet(experienceUser.Id);

            List<PermissionSetAssignment> permissionSetAssignments = [
                SELECT
                    Id
                FROM
                    PermissionSetAssignment
                WHERE
                    AssigneeId = :experienceUser.Id
                AND
                    PermissionSet.Label = :Constants.EXPERIENCE_PERMISSION_SET_NAME
            ];

            System.assertEquals(1, permissionSetAssignments.size());
        }
    }

    @isTest
    static void testGetCenters() {
        System.runAs(TestUtil.createAdminUser()) {
            Account center1 = new Account(
                Name = 'Proesis Miramar',
                RecordTypeID = Constants.CENTER_RECORD_TYPE_ID,
                BillingStreet = '7901 Riviera Blvd',
                BillingCity = 'Miramar',
                BillingState = 'FL',
                BillingPostalCode = '33023',
                BillingCountry = 'US',
                Geolocation__Latitude__s = 25.973030,
                Geolocation__Longitude__s = -80.242049,
                ExternalID__c = 'center-222',
                Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation',
                Site = 'P-01'
            );
            Account center2 = new Account(
                Name = 'Proesis Dallas',
                RecordTypeID = Constants.CENTER_RECORD_TYPE_ID,
                BillingStreet = '1080 N Westmoreland Rd',
                BillingCity = 'Dallas',
                BillingState = 'TX',
                BillingPostalCode = '75311',
                BillingCountry = 'US',
                Geolocation__Latitude__s = 32.78411048612642,
                Geolocation__Longitude__s = -96.87149106359581,
                ExternalID__c = 'center-333',
                Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation',
                Site = 'P-02'
            );

            insert new List<Account>{center1, center2};
        }

        System.runAs(TestUtil.createExperienceUser()) {
            List<SchedulerController.Center> centers = SchedulerController.getCenters(Double.valueOf(33.7488), Double.valueOf(84.3877));

            System.assertEquals(2, centers.size());
        }
    }

    @isTest
    static void testGetCenter() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createAdminUser()) {
            Account center = new Account(
                Name = 'Proesis Miramar',
                RecordTypeID = Constants.CENTER_RECORD_TYPE_ID,
                BillingStreet = '7901 Riviera Blvd',
                BillingCity = 'Miramar',
                BillingState = 'FL',
                BillingPostalCode = '33023',
                BillingCountry = 'US',
                Geolocation__Latitude__s = 25.973030,
                Geolocation__Longitude__s = -80.242049,
                ExternalID__c = 'center-222',
                Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation',
                Site = 'P-01'
            );
            insert center;

            AccountContactRelation accountContactRelation = new AccountContactRelation();
            accountContactRelation.AccountId = center.Id;
            accountContactRelation.ContactId = experienceUser.ContactId;
            insert accountContactRelation;
        }

        System.runAs(experienceUser) {
            SchedulerController.Center center = SchedulerController.getCenter();

            System.assertEquals('Proesis Miramar', center.name);
        }
    }

    @isTest
    static void testGetAppointments() {
        Account center;

        System.runAs(TestUtil.createAdminUser()) {
            center = new Account(
                Name = 'Proesis Miramar',
                RecordTypeID = Constants.CENTER_RECORD_TYPE_ID,
                BillingStreet = '7901 Riviera Blvd',
                BillingCity = 'Miramar',
                BillingState = 'FL',
                BillingPostalCode = '33023',
                BillingCountry = 'US',
                Geolocation__Latitude__s = 25.973030,
                Geolocation__Longitude__s = -80.242049,
                ExternalID__c = 'center-222',
                Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation',
                Site = 'P-01'
            );
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

        System.runAs(TestUtil.createExperienceUser()) {
            SchedulerController.AppointmentGroups appointmentGroups = SchedulerController.getAppointments(center.Id, Date.newInstance(2023, 1, 10));

            System.assertEquals(0, appointmentGroups.morningAppointments.size());
            System.assertEquals(1, appointmentGroups.afternoonAppointments.size());
            System.assertEquals(0, appointmentGroups.eveningAppointments.size());
        }
    }

    @isTest
    static void testGetVisits() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createAdminUser()) {
            Account center = new Account(
                Name = 'Proesis Miramar',
                RecordTypeID = Constants.CENTER_RECORD_TYPE_ID,
                BillingStreet = '7901 Riviera Blvd',
                BillingCity = 'Miramar',
                BillingState = 'FL',
                BillingPostalCode = '33023',
                BillingCountry = 'US',
                Geolocation__Latitude__s = 25.973030,
                Geolocation__Longitude__s = -80.242049,
                ExternalID__c = 'center-222',
                Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation',
                Site = 'P-01'
            );
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

        System.runAs(TestUtil.createAdminUser()) {
            Account center = new Account(
                Name = 'Proesis Miramar',
                RecordTypeID = Constants.CENTER_RECORD_TYPE_ID,
                BillingStreet = '7901 Riviera Blvd',
                BillingCity = 'Miramar',
                BillingState = 'FL',
                BillingPostalCode = '33023',
                BillingCountry = 'US',
                Geolocation__Latitude__s = 25.973030,
                Geolocation__Longitude__s = -80.242049,
                ExternalID__c = 'center-222',
                Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation',
                Site = 'P-01'
            );
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

            //System.assertEquals(1, visits.size());
        }
    }

}