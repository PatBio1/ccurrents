public without sharing class ProfileController {

    public static final Integer MAX_EMAIL_VERIFICATION_CODES = 3;
    public static final Integer MAX_EMAIL_VERIFICATION_ATTEMPTS = 3;
    public static final Integer MAX_SMS_VERIFICATION_CODES = 3;
    public static final Integer MAX_SMS_VERIFICATION_ATTEMPTS = 3;

    @AuraEnabled
    public static Id upsertLead(Profile profile) {
        if (String.isNotEmpty(profile.email)) {
            List<List<SObject>> matchingEmailSObjects = [FIND :profile.email IN EMAIL FIELDS RETURNING User, Lead];
            if (matchingEmailSObjects != null && matchingEmailSObjects.size() > 0 && (matchingEmailSObjects[0].size() > 0 || matchingEmailSObjects[1].size() > 0)) {
                List<Lead> matchingLeads = (List<Lead>) matchingEmailSObjects[1];

                if ((matchingLeads.size() == 1 && matchingLeads[0].Id != profile.id) || matchingLeads.size() > 1) {
                    throw new AuraHandledException('The provided email address is already in use.');
                }
            }
        }

        try {
            Util.testExceptionHandling();

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

            User user = createUser(leadConvertResult.getAccountId(), profile.language);

            Id userId = Site.createExternalUser(user, leadConvertResult.getAccountId(), profile.password, false);

            return userId;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static Id createUserFromScheduler(Profile profile) {
        try {
            Database.LeadConvertResult leadConvertResult = convertLead(profile);

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
    public static void deactivateUser(Id userId) {
        try {
            Util.testExceptionHandling();

            User user = new User();
            user.Id = userId;
            user.IsActive = false;
            update user;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
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
            First_Visit_Code__c = ScheduleUtils.createFirstVisitCode()
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

    @future
    private static void commitUserFromScheduler(Id accountId, String language) {
        Database.DMLOptions userEmailOptions = new Database.DMLOptions();
        userEmailOptions.EmailHeader.triggerUserEmail = true;
        userEmailOptions.EmailHeader.triggerOtherEmail = true;
        userEmailOptions.EmailHeader.triggerAutoResponseEmail = true;

        User user = createUser(accountId, language);
        user.setOptions(userEmailOptions);
        insert user;

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
        public Id photoContentVersionId {get; set;}

        @AuraEnabled
        public String language {get; set;}

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
        public String nickname {get; set;}

        @AuraEnabled
        public String password {get; set;}

        @AuraEnabled
        public String emailCode {get; set;}

        @AuraEnabled
        public String smsCode {get; set;}

    }

}