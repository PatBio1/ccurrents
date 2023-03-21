public with sharing class TestUtil {

    public static Boolean throwException = false;

    public static User createAdminUser() {
        UserRole userRole = new UserRole(
            Name = 'AdminTest'
        );
        insert userRole;

        String userEmail = 'admin@' + UserInfo.getOrganizationId() + '.test.com';

        User user = new User(
            FirstName = 'Admin',
            LastName = 'User',
            Email = userEmail,
            Username = userEmail,
            Alias = 'admin',
            Phone = '800-555-1212',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'ISO-8859-1',
            LanguageLocaleKey = 'en_US',
            UserRoleId = userRole.Id
        );
        insert user;

        PermissionSet adminPermissionSet = [SELECT Id FROM PermissionSet WHERE Label = :Constants.ADMIN_PERMISSION_SET_NAME];

        insert new PermissionSetAssignment(
            PermissionSetId = adminPermissionSet.Id,
            AssigneeId = user.Id
        );

        return user;
    }

    public static User createExperienceUser() {
        UserRole userRole = new UserRole(
            Name = 'Test'
        );
        insert userRole;

        String userWithRoleEmail = 'userwithrole@' + UserInfo.getOrganizationId() + '.test.com';

        User userWithRole = new User(
            FirstName = 'Role',
            LastName = 'User',
            Email = userWithRoleEmail,
            Username = userWithRoleEmail,
            Alias = 'withrole',
            Phone = '800-555-1212',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'ISO-8859-1',
            LanguageLocaleKey = 'en_US',
            UserRoleId = userRole.Id
        );
        insert userWithRole;

        Account account;
        Contact contact;
        User experienceUser;

        System.runAs(userWithRole) {
            Account = new Account(
                FirstName = 'Test',
                LastName = 'Last',
                First_Visit_Code__c = ScheduleUtils.createFirstVisitCode(),
                RecordTypeId = Constants.DONOR_RECORD_TYPE_ID
            );
            insert account;

            String experienceUserEmail = 'experience@' + UserInfo.getOrganizationId() + '.test.com';

            experienceUser = new User(
                FirstName = 'Experience',
                LastName = 'User',
                Email = experienceUserEmail,
                Username = experienceUserEmail + Constants.USERNAME_SUFFIX,
                Alias = 'experien',
                Phone = '800-555-1212',
                ProfileId = [SELECT Id FROM Profile WHERE Name = :Constants.EXPERIENCE_USER_PROFILE_NAME].Id,
                TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'ISO-8859-1',
                LanguageLocaleKey = 'en_US',
                ContactId = [SELECT PersonContactId FROM Account WHERE Id = :account.Id LIMIT 1].PersonContactId
            );
            insert experienceUser;
        }

        return experienceUser;
    }

    public static User createExperienceGuestUser() {
        return new User(Id = UserInfo.getUserId());
    }

    public static User createExperienceUserFromContactId(Id contactId) {
        String experienceUserEmail = 'experience@' + UserInfo.getOrganizationId() + 'contactId.test.com';
        User experienceUser = new User(
            FirstName = 'Experience',
            LastName = 'User2',
            Email = experienceUserEmail,
            Username = experienceUserEmail,
            Alias = 'expe2',
            Phone = '800-555-1212',
            ProfileId = [SELECT Id FROM Profile WHERE Name = :Constants.EXPERIENCE_USER_PROFILE_NAME].Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'ISO-8859-1',
            LanguageLocaleKey = 'en_US',
            ContactId = contactId
        );
        insert experienceUser;
        return experienceUser;
    }

    public static Account createHQCenter() {
        return new Account(
            Name = 'Proesis HQ',
            RecordTypeId = Constants.CENTER_RECORD_TYPE_ID,
            BillingPostalCode = '33023',
            BillingCountry = 'US',
            CenterId__c = 'center-111',
            Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation',
            Site = 'P-00',
            IsActive__c = false
        );
    }

    public static Account createMiramarCenter() {
        return new Account(
            Name = 'Proesis Miramar',
            RecordTypeId = Constants.CENTER_RECORD_TYPE_ID,
            BillingStreet = '7901 Riviera Blvd',
            BillingCity = 'Miramar',
            BillingState = 'FL',
            BillingPostalCode = '33023',
            BillingCountry = 'US',
            Geolocation__Latitude__s = 25.973030,
            Geolocation__Longitude__s = -80.242049,
            CenterId__c = 'center-222',
            Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation',
            Site = 'P-01',
            IsActive__c = true
        );
    }

    public static Account createDallasCenter() {
        return new Account(
            Name = 'Proesis Dallas',
            RecordTypeId = Constants.CENTER_RECORD_TYPE_ID,
            BillingStreet = '1080 N Westmoreland Rd',
            BillingCity = 'Dallas',
            BillingState = 'TX',
            BillingPostalCode = '75311',
            BillingCountry = 'US',
            Geolocation__Latitude__s = 32.78411048612642,
            Geolocation__Longitude__s = -96.87149106359581,
            CenterId__c = 'center-333',
            Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation',
            Site = 'P-02',
            IsActive__c = true
        );
    }

    public static List<Business_Hours__c> createBusinessHours(Id centerId) {
        return new List<Business_Hours__c>{
            new Business_Hours__c(
                Center__c = centerId,
                Index__c = 1, // Sunday
                isclosed__c = true
            ),
            new Business_Hours__c(
                Center__c = centerId,
                Index__c = 2, // Monday
                Open__c = Time.newInstance(6, 0, 0, 0), // 6AM
                Close__c = Time.newInstance(21, 0, 0, 0) // 9PM
            ),
            new Business_Hours__c(
                Center__c = centerId,
                Index__c = 3, // Tuesday
                Open__c = Time.newInstance(6, 0, 0, 0), // 6AM
                Close__c = Time.newInstance(21, 0, 0, 0) // 9PM
            ),
            new Business_Hours__c(
                Center__c = centerId,
                Index__c = 4, // Wednesday
                Open__c = Time.newInstance(6, 0, 0, 0), // 6AM
                Close__c = Time.newInstance(21, 0, 0, 0) // 9PM
            ),
            new Business_Hours__c(
                Center__c = centerId,
                Index__c = 5, // Thursday
                Open__c = Time.newInstance(6, 0, 0, 0), // 6AM
                Close__c = Time.newInstance(21, 0, 0, 0) // 9PM
            ),
            new Business_Hours__c(
                Center__c = centerId,
                Index__c = 6, // Friday
                Open__c = Time.newInstance(6, 0, 0, 0), // 6AM
                Close__c = Time.newInstance(21, 0, 0, 0) // 9PM
            ),
            new Business_Hours__c(
                Center__c = centerId,
                Index__c = 7, // Saturday
                Open__c = Time.newInstance(8, 0, 0, 0), // 8AM
                Close__c = Time.newInstance(18, 0, 0, 0) // 6PM
            )
        };
    }

    public static Account createTestDonor(String donorId) {
        return new Account(
            RecordTypeId = Constants.DONOR_RECORD_TYPE_ID,
            FirstName = 'Test',
            LastName = 'Donor',
            DonorId__c = donorId
        );
    }

    public static Schedule__c createTestSchedule(Id centerId, Datetime testDateTime) {
        return new Schedule__c(
            Center__c = centerId,
            Begin_Date__c = Date.valueOf(testDateTime).addDays(-1),
            End_Date__c = Date.valueOf(testDateTime).addDays(1)
        );
    }

    public static Appointment__c createTestAppointment(Id scheduleId, Datetime testDateTime) {
        Integer testDateTimeHour = testDateTime.hourGmt();
        Time appointmentTime = Time.newInstance(testDateTimeHour, 0, 0, 0);
        Date appointmentDate = testDateTime.dateGmt();
        Datetime appointmentDateTime = Datetime.newInstanceGmt(appointmentDate, appointmentTime);
        return new Appointment__c(
            Schedule__c = scheduleId,
            Duration__c = 15,
            Capacity__c = 4,
            Datetime__c = appointmentDateTime
        );
    }

    public static Center_Donation_Type__c createCenterDonationType(Id centerId) {
        Donation_Type__c donationType = new Donation_Type__c(Name = 'Normal Source Plasma');
        insert donationType;
        return new Center_Donation_Type__c(
            isActive__c = true,
            Center__c = centerId,
            Donation_Type__c = donationType.Id
        );
    }

    public static Visit__c createVisit(Id donorId, Id centerDonationTypeId, Id appointmentId) {
        return new Visit__c(
            Donor__c = donorId,
            Center_Donation_Type__c = centerDonationTypeId,
            Appointment__c = appointmentId,
            Status__c = 'New'
        );
    }

    public static AccountContactRelation createDonorCenterRelation(Id donorId, Id centerId) {
        return new AccountContactRelation(
            AccountId = centerId,
            ContactId = donorId,
            Roles = 'Donor',
            IsActive = true
        );
    }

    public static VisitTestSetup createFullTestVisitSetup(String donorExternalId, Datetime testDateTime, Boolean createExperienceUser) {
        Id donorId;
        Id donorContactId;
        if (createExperienceUser) {
            User donorUser = createExperienceUser();
            donorContactId = donorUser.ContactId;
            donorId = donorUser.AccountId;
        } else {
            Account donor = createTestDonor(donorExternalId);
            insert donor;
            donorContactId = [SELECT PersonContactId FROM Account WHERE Id = :donor.Id][0].PersonContactId;
        }

        Account center = createMiramarCenter();
        insert center;
        AccountContactRelation donorCenterRelation = createDonorCenterRelation(donorContactId, center.Id);
        insert donorCenterRelation;
        Schedule__c schedule = createTestSchedule(center.Id, testDateTime);
        insert schedule;
        Appointment__c appointment = createTestAppointment(schedule.Id, testDateTime);
        insert appointment;
        Center_Donation_Type__c centerDonationType = createCenterDonationType(center.Id);
        insert centerDonationType;
        Visit__c visit = createVisit(donorContactId, centerDonationType.Id, appointment.Id);
        insert visit;

        VisitTestSetup testSetup = new VisitTestSetup();
        testSetup.DonorId = donorId;
        testSetup.DonorContactId = donorContactId;
        testSetup.CenterId = center.Id;
        testSetup.DonorCenterRelationId = donorCenterRelation.Id;
        testSetup.ScheduleId = schedule.Id;
        testSetup.AppointmentId = appointment.Id;
        testSetup.CenterDonationTypeId = centerDonationType.Id;
        testSetup.VisitId = visit.Id;

        return testSetup;
    }

    public static ContentVersion createContentVersion() {
        return new ContentVersion(
            Title = 'Test',
            PathOnClient = 'test.txt',
            VersionData = Blob.valueOf('data')
        );
    }

    public class VisitTestSetup {
        public Id DonorId;
        public Id DonorContactId;
        public Id CenterId;
        public Id DonorCenterRelationId;
        public Id ScheduleId;
        public Id AppointmentId;
        public Id CenterDonationTypeId;
        public Id VisitId;
    }

    public class TestException extends Exception {
    }

}