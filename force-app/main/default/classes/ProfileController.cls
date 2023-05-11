public without sharing class ProfileController {

    public static final Integer MAX_EMAIL_VERIFICATION_CODES = 3;
    public static final Integer MAX_EMAIL_VERIFICATION_ATTEMPTS = 3;
    public static final Integer MAX_SMS_VERIFICATION_CODES = 3;
    public static final Integer MAX_SMS_VERIFICATION_ATTEMPTS = 3;

    @AuraEnabled
    public static Id upsertLead(Profile profile) {
        try {
            Util.testExceptionHandling();

            if (String.isNotEmpty(profile.email)) {
                List<List<SObject>> matchingEmailSObjects = [FIND :profile.email IN EMAIL FIELDS RETURNING User, Lead];
                if (matchingEmailSObjects != null && matchingEmailSObjects.size() > 0 && (matchingEmailSObjects[0].size() > 0 || matchingEmailSObjects[1].size() > 0)) {
                    List<Lead> matchingLeads = (List<Lead>) matchingEmailSObjects[1];
    
                    if ((matchingLeads.size() == 1 && matchingLeads[0].Id != profile.id) || matchingLeads.size() > 1) {
                        throw new AuraHandledException('The provided email address is already in use.');
                    }
                }
            }

            Lead lead = new Lead();
            lead.Id = profile.id;
            lead.FirstName = profile.firstName;
            lead.MiddleName = profile.middleName;
            lead.LastName = profile.lastName;
            lead.Suffix = profile.suffix;
            lead.Preferred_Name__c = profile.nickname;
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
    public static String setupPhoto(Profile profile) {
        try {
            Util.testExceptionHandling();

            // Create a Content Delivery for the uploaded file to get
            // a public URL to be able to view it as guest user.
            MobileGuestService.GetDownloadUrlRequest getDownloadUrlRequest = new MobileGuestService.GetDownloadUrlRequest();
            getDownloadUrlRequest.contentVersionId = profile.photoContentVersionId;

            String endpoint = MobileGuestService.ENDPOINT + MobileGuestService.GET_DOWNLOAD_URL_PATH;

            HttpRequest httpRequest = new HttpRequest();
            httpRequest.setMethod('POST');
            httpRequest.setEndpoint(endpoint);
            httpRequest.setHeader('Content-Type', 'application/json;charset=UTF-8');
            httpRequest.setBody(JSON.serialize(getDownloadUrlRequest));

            HttpResponse httpResponse = new Http().send(httpRequest);

            ContentVersion contentVersion = [
                SELECT
                    ContentDocumentId
                FROM
                    ContentVersion
                WHERE
                    Id = :profile.photoContentVersionId
            ];

            // Update title on the uploaded file.
            ContentDocument contentDocument = new ContentDocument();
            contentDocument.Id = contentVersion.ContentDocumentId;
            contentDocument.Title = 'Profile Photo';
            update contentDocument;

            // Link the uploaded file to the Lead record.
            ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
            contentDocumentLink.LinkedEntityId = profile.id;
            contentDocumentLink.ContentDocumentId = contentVersion.ContentDocumentId;
            insert contentDocumentLink;

            // Return public url for uploaded file.
            MobileGuestService.GetDownloadUrlResponse getDownloadUrlResponse = (MobileGuestService.GetDownloadUrlResponse) JSON.deserialize(httpResponse.getBody(), MobileGuestService.GetDownloadUrlResponse.class);
            return getDownloadUrlResponse.downloadUrl;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static void removePhoto(Id contentVersionId) {
        try {
            Util.testExceptionHandling();

            ContentVersion contentVersion = [
                SELECT
                    ContentDocumentId
                FROM
                    ContentVersion
                WHERE
                    Id = :contentVersionId
            ];

            Database.delete(contentVersion.ContentDocumentId);
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static Boolean sendVerificationEmail(Profile profile) {
        try {
            Util.testExceptionHandling();

            Lead lead = [SELECT Email_Verification_Codes_Sent__c FROM Lead WHERE Id = :profile.id];

            Integer emailVerificationCodesSent = (lead.Email_Verification_Codes_Sent__c == null ? 0 : lead.Email_Verification_Codes_Sent__c.intValue());

            if (emailVerificationCodesSent < MAX_EMAIL_VERIFICATION_CODES) {
                lead.Email_Verification_Code__c = Util.generateVerificationCode();
                lead.Email_Verification_Codes_Sent__c = emailVerificationCodesSent + 1;
                lead.Email_Verification_Attempts__c = 0;
                update lead;

                Id orgWideEmailId = Util.getOrgWideEmailAddress(Constants.ORG_WIDE_EMAIL_NAME);

                Id verificationCodeTemplateId = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Verification_Code'].Id;

                Messaging.SingleEmailMessage emailMessage = new Messaging.SingleEmailMessage();
                emailMessage.setOrgWideEmailAddressId(orgWideEmailId);
                emailMessage.setTemplateId(verificationCodeTemplateId);
                emailMessage.setTargetObjectId(lead.Id);
    
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{emailMessage});

                return true;
            } else {
                return false;
            }
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static String verifyEmailCode(Profile profile) {
        try {
            Util.testExceptionHandling();

            Lead lead = [SELECT Email_Verification_Code__c, Email_Verification_Attempts__c FROM Lead WHERE Id = :profile.id];

            Integer emailVerificationAttempts = (lead.Email_Verification_Attempts__c == null ? 0 : lead.Email_Verification_Attempts__c.intValue());

            if (emailVerificationAttempts < MAX_EMAIL_VERIFICATION_ATTEMPTS) {
                if (profile.emailCode == lead.Email_Verification_Code__c) {
                    lead.isEmailVerified__c = true;
                    update lead;
    
                    return Constants.VERIFICATION_RESULT_SUCCESS;
                } else {
                    lead.Email_Verification_Attempts__c = emailVerificationAttempts + 1;
                    update lead;

                    if (lead.Email_Verification_Attempts__c < MAX_EMAIL_VERIFICATION_ATTEMPTS) {
                        return Constants.VERIFICATION_RESULT_INCORRECT;
                    } else {
                        return Constants.VERIFICATION_RESULT_TOO_MANY;
                    }
                }
            } else {
                return Constants.VERIFICATION_RESULT_TOO_MANY;
            }
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static Boolean smsVerificationEnabled() {
        try {
            Util.testExceptionHandling();

            Proesis_Settings__c proesisSettings = Proesis_Settings__c.getOrgDefaults();

            return (proesisSettings?.SMS_Verification_Enabled__c == true);
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static Boolean sendVerificationSms(Profile profile) {
        try {
            Util.testExceptionHandling();

            Lead lead = [SELECT SMS_Verification_Codes_Sent__c FROM Lead WHERE Id = :profile.id];

            Integer smsVerificationCodesSent = (lead.SMS_Verification_Codes_Sent__c == null ? 0 : lead.SMS_Verification_Codes_Sent__c.intValue());

            if (smsVerificationCodesSent < MAX_SMS_VERIFICATION_CODES) {
                lead.SMS_Verification_Code__c = Util.generateVerificationCode();
                lead.SMS_Verification_Codes_Sent__c = smsVerificationCodesSent + 1;
                lead.SMS_Verification_Attempts__c = 0;
                update lead;

                // TODO - send code via SMS.

                return true;
            } else {
                return false;
            }
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static String verifySmsCode(Profile profile) {
        try {
            Util.testExceptionHandling();

            Lead lead = [SELECT SMS_Verification_Code__c, SMS_Verification_Attempts__c FROM Lead WHERE Id = :profile.id];

            Integer smsVerificationAttempts = (lead.SMS_Verification_Attempts__c == null ? 0 : lead.SMS_Verification_Attempts__c.intValue());

            if (smsVerificationAttempts < MAX_SMS_VERIFICATION_ATTEMPTS) {
                if (profile.smsCode == lead.SMS_Verification_Code__c) {
                    lead.isSMSVerified__c = true;
                    update lead;
    
                    return Constants.VERIFICATION_RESULT_SUCCESS;
                } else {
                    lead.SMS_Verification_Attempts__c = smsVerificationAttempts + 1;
                    update lead;

                    if (lead.SMS_Verification_Attempts__c < MAX_SMS_VERIFICATION_ATTEMPTS) {
                        return Constants.VERIFICATION_RESULT_INCORRECT;
                    } else {
                        return Constants.VERIFICATION_RESULT_TOO_MANY;
                    }
                }
            } else {
                return Constants.VERIFICATION_RESULT_TOO_MANY;
            }
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static Id createUser(Profile profile) {
        try {
            Util.testExceptionHandling();

            Database.LeadConvertResult leadConvertResult = convertLead(profile);

            if (profile.isAcceptingMarketingComms == true) {
                handleCreateMarketingConsent(leadConvertResult.getLeadId(), leadConvertResult.getContactId());
            }

            User user = createUser(leadConvertResult.getAccountId(), profile.language);

            Id userId = Site.createExternalUser(user, leadConvertResult.getAccountId(), profile.password, false);

            update new Account(
                Id = leadConvertResult.getAccountId(),
                User__pc = userId
            );

            return userId;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static Id createUserFromScheduler(Profile profile) {
        try {
            Database.LeadConvertResult leadConvertResult = convertLead(profile);

            // Update the account record with the address info from the profile
            // This issue doesn't happen on the mobile app, perhaps because of the createExternalUser call?
            update new Account(
                Id = leadConvertResult.getAccountId(),
                PersonMailingStreet = profile.street,
                PersonMailingCity = profile.city,
                PersonMailingState = profile.state,
                PersonMailingPostalCode = profile.postalCode,
                PersonMailingCountry = 'US' // We are hard coding US as that is what the Onbe API requires for the createAccount callout
            );

            commitUserFromScheduler(leadConvertResult.getAccountId(), profile.language);

            return leadConvertResult.getAccountId();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void setupUser(Profile profile) {
        try {
            Util.testExceptionHandling();

            // Set profile photo on User record.
            if (profile.photoContentVersionId != null) {
                MobileGuestService.SetUserPhotoRequest setUserPhotoRequest = new MobileGuestService.SetUserPhotoRequest();
                setUserPhotoRequest.userId = profile.userId;
                setUserPhotoRequest.contentVersionId = profile.photoContentVersionId;

                String endpoint = MobileGuestService.ENDPOINT + MobileGuestService.SET_USER_PHOTO_PATH;

                HttpRequest httpRequest = new HttpRequest();
                httpRequest.setMethod('POST');
                httpRequest.setEndpoint(endpoint);
                httpRequest.setHeader('Content-Type', 'application/json;charset=UTF-8');
                httpRequest.setBody(JSON.serialize(setUserPhotoRequest));

                HttpResponse httpResponse = new Http().send(httpRequest);
            }

            assignUserPermissionSet(profile.userId);
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static Profile getProfile() {
        try {
            Util.testExceptionHandling();

            User user = [SELECT ContactId, LanguageLocaleKey FROM User WHERE Id = :UserInfo.getUserId()];

            Contact contact = [
                SELECT
                    Salutation, FirstName, MiddleName, LastName, Suffix, Email, MobilePhone, HomePhone,
                    Height__c, How_will_you_get_to_the_Center__c, MailingStreet, Street_Line_2__c,
                    MailingCity, MailingState, MailingPostalCode, Weight__c,
                    (SELECT Account.Name FROM AccountContactRelations WHERE Roles INCLUDES ('Donor'))
                FROM
                    Contact
                WHERE
                    Id = :user.ContactId
            ];

            Profile profile = new Profile();
            profile.prefix = contact.Salutation;
            profile.firstName = contact.FirstName;
            profile.middleName = contact.MiddleName;
            profile.lastName = contact.LastName;
            profile.suffix = contact.Suffix;
            profile.email = contact.Email;
            profile.mobilePhone = contact.MobilePhone;
            profile.homePhone = contact.HomePhone;
            profile.height = contact.Height__c;
            profile.centerName = contact.AccountContactRelations[0].Account.Name;
            profile.howGetToCenter = contact.How_will_you_get_to_the_Center__c;
            profile.street = contact.MailingStreet;
            profile.street2 = contact.Street_Line_2__c;
            profile.city = contact.MailingCity;
            profile.state = contact.MailingState;
            profile.postalCode = contact.MailingPostalCode;
            profile.language = (user.LanguageLocaleKey.startsWith('es') ? 'es_US' : 'en_US');
            profile.weight = contact.Weight__c;

            return profile;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static String changeProfile(Profile profile) {
        try {
            Util.testExceptionHandling();

            User user = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];

            List<Visit__c> visits = [
                SELECT
                    Appointment__r.Datetime__c
                FROM
                    Visit__c
                WHERE
                    Donor__c = :user.ContactId
                AND
                    Appointment__r.Datetime__c > :DateTime.now()
                AND
                    Status__c != 'Complete'
                ORDER BY
                    Appointment__r.Datetime__c ASC
                LIMIT
                    1
            ];

            Map<String,Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();

            List<Field> fields = new List<Field>{
                new Field('prefix', contactFields.get('Salutation').getDescribe().getlabel()),
                new Field('firstName', contactFields.get('FirstName').getDescribe().getlabel()),
                new Field('middleName', contactFields.get('MiddleName').getDescribe().getlabel()),
                new Field('lastName', contactFields.get('LastName').getDescribe().getlabel()),
                new Field('suffix', contactFields.get('Suffix').getDescribe().getlabel()),
                new Field('email', contactFields.get('Email').getDescribe().getlabel()),
                new Field('mobilePhone', contactFields.get('MobilePhone').getDescribe().getlabel()),
                new Field('homePhone', contactFields.get('HomePhone').getDescribe().getlabel()),
                new Field('height', contactFields.get('Height__c').getDescribe().getlabel()),
                new Field('street', contactFields.get('MailingStreet').getDescribe().getlabel()),
                new Field('street2', contactFields.get('Street_Line_2__c').getDescribe().getlabel()),
                new Field('city', contactFields.get('MailingCity').getDescribe().getlabel()),
                new Field('state', contactFields.get('MailingState').getDescribe().getlabel()),
                new Field('postalCode', contactFields.get('MailingPostalCode').getDescribe().getlabel()),
                new Field('weight', contactFields.get('Weight__c').getDescribe().getlabel())
            };

            Profile existingProfile = getProfile();

            Map<String, Object> existingValues = (Map<String,Object>) JSON.deserializeUntyped(JSON.serialize(existingProfile));
            Map<String, Object> values = (Map<String,Object>) JSON.deserializeUntyped(JSON.serialize(profile));

            List<String> fieldValues = new List<String>();

            for (Field field : fields) {
                String existingValue = String.valueOf(existingValues.get(field.name));
                String value = String.valueOf(values.get(field.name));
                Boolean valuesEqual = (existingValue == value);

                String fieldValue = (valuesEqual ? '' : '*') + field.label + ': ' + value;
                fieldValues.add(fieldValue);
            }

            Task task = new Task();
            task.WhoId = user.ContactId;
            task.WhatId = visits[0].Id;
            task.Subject = 'Information Change';
            task.Description = String.join(fieldValues, '\n');
            insert task;

            String nextVisitTime = visits[0].Appointment__r.Datetime__c.format('E, d MMM ‘YY h:mm a');

            return String.format(Label.Profile_Change_Confirmation, new List<String>{nextVisitTime});
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static void deactivateUser(Id userId) {
        try {
            Util.testExceptionHandling();

            User user = new User();
            user.Id = userId;
            user.IsActive = false;
            update user;

            cancelFutureVisits(userId);
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @future
    private static void cancelFutureVisits(Id userid) {
        User user = [SELECT ContactId FROM User WHERE Id = :userId];

        List<Visit__c> visits = [
            SELECT
                Id
            FROM
                Visit__c
            WHERE
                Donor__c = :user.ContactId
            AND
                Appointment__r.Datetime__c > :DateTime.now()
        ];

        if (visits.size() > 0) {
            for (Visit__c visit : visits) {
                visit.Status__c = 'Complete';
                visit.Outcome__c = 'Canceled';
            }

            update visits;
        }
    }

    private static Database.LeadConvertResult convertLead(Profile profile) {
        LeadStatus leadStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];

        Database.LeadConvert leadConvert = new Database.LeadConvert();
        leadConvert.setLeadId(profile.id);
        leadConvert.setConvertedStatus(leadStatus.MasterLabel);
        leadConvert.setDoNotCreateOpportunity(true);

        Database.LeadConvertResult leadConvertResult = Database.convertLead(leadConvert);

        update new Account(
            Id = leadConvertResult.getAccountId(),
            RecordTypeId = Constants.DONOR_RECORD_TYPE_ID,
            Loyalty_Level__pc = LoyaltyLevelService.getDefault().Id,
            First_Visit_Code__c = ScheduleUtils.createFirstVisitCode(),
            Status__pc = 'Registered',
            Last_Used_Center__pc = profile.centerId
        );

        AccountContactRelation accountContactRelation = new AccountContactRelation();
        accountContactRelation.AccountId = profile.centerId;
        accountContactRelation.ContactId = leadConvertResult.getContactId();
        accountContactRelation.Roles = 'Donor';
        insert accountContactRelation;

        return leadConvertResult;
    }

    private static void assignUserPermissionSet(Id userId) {
        PermissionSet permissionSet = [SELECT Id FROM PermissionSet WHERE Label = :Constants.EXPERIENCE_PERMISSION_SET_NAME];

        PermissionSetAssignment permissionSetAssignment = new PermissionSetAssignment();
        permissionSetAssignment.PermissionSetId = permissionSet.Id;
        permissionSetAssignment.AssigneeId = userId;
        insert permissionSetAssignment;
    }

    public static User createUser(Id accountId, String language) {
        Account account = [SELECT FirstName, LastName, PersonEmail, PersonContactId FROM Account WHERE Id = :accountId LIMIT 1];

        String alias = (account.FirstName.trim().replaceAll('[^a-zA-Z]', '') + account.LastName.trim().replaceAll('[^a-zA-Z]', '')).abbreviate(8);
        String username = account.PersonEmail + Constants.USERNAME_SUFFIX;

        User user = new user();
        user.FirstName = account.FirstName;
        user.LastName = account.LastName;
        user.Email = account.PersonEmail;
        user.Alias = alias;
        user.Username = username;
        user.CommunityNickname = 'proesis' + System.currentTimeMillis();
        user.LocaleSidKey = language;
        user.TimeZoneSidKey = 'America/New_York';
        user.ProfileId = [SELECT Id FROM Profile WHERE Name = :Constants.EXPERIENCE_USER_PROFILE_NAME].Id;
        user.LanguageLocaleKey = (language.startsWith('es') ? 'es' : 'en_US');
        user.EmailEncodingKey = 'UTF-8';
        user.ContactId = account.PersonContactId;
        user.IsActive = true;

        return user;
    }

    @TestVisible
    private static void handleCreateMarketingConsent(Id leadId, Id contactId) {
        insert new Consent_Transaction__c(
            Lead__c = leadId,
            Contact__c = contactId,
            Scope__c = Constants.DEFAULT_MARKETING_CONSENT_SCOPE,
            Source__c = Constants.DEFAULT_MARKETING_CONSENT_SOURCE,
            Type_of_Consent__c = Constants.DEFAULT_MARKETING_CONSENT_TYPE,
            Date_Time_of_Consent__c = System.today()
        );
    }

    @future
    private static void commitUserFromScheduler(Id accountId, String language) {
        Database.DMLOptions userEmailOptions = new Database.DMLOptions();
        userEmailOptions.EmailHeader.triggerUserEmail = true;
        userEmailOptions.EmailHeader.triggerOtherEmail = true;
        userEmailOptions.EmailHeader.triggerAutoResponseEmail = true;

        User user = createUser(accountId, language);
        user.setOptions(userEmailOptions);
        insert user;

        update new Account(
            Id = accountId,
            User__pc = user.Id
        );

        assignUserPermissionSet(user.Id);
    }

    public class Profile {

        @AuraEnabled
        public Id id {get; set;}

        @AuraEnabled
        public Id userId {get; set;}

        @AuraEnabled
        public Id centerId {get; set;}

        @AuraEnabled
        public String centerName {get; set;}

        @AuraEnabled
        public Id photoContentVersionId {get; set;}

        @AuraEnabled
        public String language {get; set;}

        @AuraEnabled
        public String prefix {get; set;}

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
        public String homePhone {get; set;}

        @AuraEnabled
        public Decimal height {get; set;}

        @AuraEnabled
        public Decimal weight {get; set;}

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
        public String nickname {get; set;}

        @AuraEnabled
        public String password {get; set;}

        @AuraEnabled
        public String emailCode {get; set;}

        @AuraEnabled
        public String smsCode {get; set;}

        @AuraEnabled
        public Boolean isAcceptingMarketingComms {get; set;}

    }

    public class Field {

        public String name;
        public String label;

        public Field(String name, String label) {
            this.name = name;
            this.label = label;
        }

    }

}