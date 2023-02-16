public with sharing class TestUtil {

    public static Boolean throwException = false;

    public static User createAdminUser() {
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
            LanguageLocaleKey = 'en_US'
        );
        insert user;

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
                    RecordTypeId = Constants.DONOR_RECORD_TYPE_ID
            );
            insert account;

            Id personContactId = [SELECT PersonContactId FROM Account WHERE Id = :account.Id][0].PersonContactId;

            String experienceUserEmail = 'experience@' + UserInfo.getOrganizationId() + '.test.com';

            experienceUser = new User(
                FirstName = 'Experience',
                LastName = 'User',
                Email = experienceUserEmail,
                Username = experienceUserEmail,
                Alias = 'experien',
                Phone = '800-555-1212',
                ProfileId = [SELECT Id FROM Profile WHERE Name = :Constants.EXPERIENCE_USER_PROFILE_NAME].Id,
                TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'ISO-8859-1',
                LanguageLocaleKey = 'en_US',
                contactId = personContactId
            );
            insert experienceUser;
        }

        return experienceUser;
    }

    public static User createExperienceGuestUser() {
        return new User(Id=UserInfo.getUserId());
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
            ExternalID__c = 'center-222',
            Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation',
            Site = 'P-01'
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
            ExternalID__c = 'center-333',
            Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation',
            Site = 'P-02'
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

    public class TestException extends Exception {}

}