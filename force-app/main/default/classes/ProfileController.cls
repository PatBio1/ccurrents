public without sharing class ProfileController {

    @AuraEnabled
    public static Id upsertLead(Profile profile) {
        try {
            Util.testExceptionHandling();

            Lead lead = new Lead();
            lead.Id = profile.id;
            lead.FirstName = profile.firstName;
            lead.MiddleName = profile.middleName;
            lead.LastName = profile.lastName;
            lead.Suffix = profile.suffix;
            lead.Email = profile.email;
            lead.MobilePhone = profile.mobilePhone;
            lead.Street = profile.street;
            lead.Street_Line_2__c = profile.street2;
            lead.City = profile.city;
            lead.State = profile.state;
            lead.PostalCode = profile.postalCode;
            lead.How_will_you_get_to_the_Center__c = profile.howGetToCenter;
            upsert lead;

            return lead.Id;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static Id createUser(Profile profile) {
        try {
            Util.testExceptionHandling();

            LeadStatus leadStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];

            Database.LeadConvert leadConvert = new Database.LeadConvert();
            leadConvert.setLeadId(profile.id);
            leadConvert.setConvertedStatus(leadStatus.MasterLabel);
            leadConvert.setDoNotCreateOpportunity(true);

            Database.LeadConvertResult lcr = Database.convertLead(leadConvert);

            System.debug(lcr);

            Id accountId = lcr.getAccountId();

            Account account = [
                SELECT
                    FirstName, LastName, PersonEmail, PersonContactId
                FROM
                    Account
                WHERE
                    Id = :accountId
            ];

            AccountContactRelation accountContactRelation = new AccountContactRelation();
            accountContactRelation.AccountId = profile.centerId;
            accountContactRelation.ContactId = lcr.getContactId();
            accountContactRelation.Roles = 'Donor';
            insert accountContactRelation;

            String nickname = account.FirstName.substring(0, 1) + account.LastName;
            String username = account.PersonEmail + Constants.USERNAME_SUFFIX;

            User user = new user();
            user.FirstName = account.FirstName;
            user.LastName = account.LastName;
            user.Email = account.PersonEmail;
            user.Alias = nickname.abbreviate(8);
            user.Username = username;
            user.CommunityNickname = nickname.abbreviate(40);
            user.LocaleSidKey = 'en_US';
            user.TimeZoneSidKey = 'America/New_York';
            user.ProfileId = [SELECT Id FROM Profile WHERE Name = :Constants.EXPERIENCE_USER_PROFILE_NAME].Id;
            user.LanguageLocaleKey = 'en_US';
            user.EmailEncodingKey = 'UTF-8';
            user.ContactId = account.PersonContactId;
            user.IsActive = true;
System.debug('### user='+user);

            Id userId = Site.createExternalUser(user, account.Id, profile.password, false);

            return userId;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static void assignPermissionSet(Id userId) {
        try {
            Util.testExceptionHandling();

            PermissionSet permissionSet = [SELECT Id FROM PermissionSet WHERE Label = :Constants.EXPERIENCE_PERMISSION_SET_NAME];

            PermissionSetAssignment psa = new PermissionSetAssignment();
            psa.PermissionSetId = permissionSet.Id;
            psa.AssigneeId = userId;
            insert psa;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    public class Profile {

        @AuraEnabled
        public Id id {get; set;}

        @AuraEnabled
        public Id centerId {get; set;}

        @AuraEnabled
        public String firstName {get; set;}

        @AuraEnabled
        public String middleName {get; set;}

        @AuraEnabled
        public String lastName {get; set;}

        @AuraEnabled
        public String suffix {get; set;}

        @AuraEnabled
        public String email {get; set;}

        @AuraEnabled
        public String mobilePhone {get; set;}

        @AuraEnabled
        public String street {get; set;}

        @AuraEnabled
        public String street2 {get; set;}

        @AuraEnabled
        public String city {get; set;}

        @AuraEnabled
        public String state {get; set;}

        @AuraEnabled
        public String postalCode {get; set;}

        @AuraEnabled
        public String howGetToCenter {get; set;}

        @AuraEnabled
        public String password {get; set;}

    }

}