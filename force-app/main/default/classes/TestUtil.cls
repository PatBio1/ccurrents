@isTest
public with sharing class TestUtil {

    public static User createAdminUser() {
        return new User(Id=UserInfo.getUserId());
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
            account = new Account(
                Name = 'Test'
            );
            insert account;

            contact = new Contact(
                AccountId = account.Id,
                LastName = 'Last'
            );
            insert contact;

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
                contactId = contact.Id
            );
            insert experienceUser;
        }

        return experienceUser;
    }

    public static User createExperienceGuestUser() {
        return new User(Id=UserInfo.getUserId());
    }

}