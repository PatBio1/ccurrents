@isTest
public with sharing class ProfileControllerTest {

    @isTest
    static void testUpsertLead() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            ProfileController.Profile profile = new ProfileController.Profile();
            profile.firstName = 'First';
            profile.middleName = 'Middle';
            profile.lastName = 'Last';

            Id leadId = ProfileController.upsertLead(profile);

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
    static void testUpsertLeadException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.upsertLead(new ProfileController.Profile());
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testSetupPhoto() {
        Lead lead;
        ContentVersion contentVersion;

        System.runAs(TestUtil.createAdminUser()) {
            lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            insert lead;

            contentVersion = TestUtil.createContentVersion();
            insert contentVersion;
        }

        System.runAs(TestUtil.createExperienceGuestUser()) {
            ProfileController.Profile profile = new ProfileController.Profile();
            profile.id = lead.Id;
            profile.photoContentVersionId = contentVersion.Id;

            MobileGuestService.GetDownloadUrlResponse getDownloadUrlResponse = new MobileGuestService.GetDownloadUrlResponse();
            getDownloadUrlResponse.downloadUrl = 'https://test.com';

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new CalloutMock(JSON.serialize(getDownloadUrlResponse)));

            String url = ProfileController.setupPhoto(profile);

            Test.stopTest();

            System.assertEquals('https://test.com', url);
        }
    }

    @isTest
    static void testSetupPhotoException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.setupPhoto(new ProfileController.Profile());
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testRemovePhoto() {
        ContentVersion contentVersion;

        System.runAs(TestUtil.createAdminUser()) {
            contentVersion = TestUtil.createContentVersion();
            insert contentVersion;
        }

        System.runAs(TestUtil.createExperienceGuestUser()) {
            ProfileController.removePhoto(contentVersion.Id);

            System.assertEquals(0, [SELECT COUNT() FROM ContentVersion WHERE Id = :contentVersion.Id]);
        }
    }

    @isTest
    static void testRemovePhotoException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.removePhoto(null);
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testSendVerificationEmail() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            Lead lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            lead.Email = 'test@test.com';
            insert lead;

            ProfileController.Profile profile = new ProfileController.Profile();
            profile.id = lead.Id;

            Boolean verificationSent = ProfileController.sendVerificationEmail(profile);

            System.assertEquals(true, verificationSent);

            Lead updatedLead = [SELECT Email_Verification_Codes_Sent__c, Email_Verification_Code__c, Email_Verification_Attempts__c FROM Lead WHERE Id = :lead.Id];

            System.assertEquals(1, updatedLead.Email_Verification_Codes_Sent__c);
            System.assert(String.isNotBlank(updatedLead.Email_Verification_Code__c));
            System.assertEquals(0, updatedLead.Email_Verification_Attempts__c);
        }
    }

    @isTest
    static void testSendVerificationEmailCodesExhausted() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            Lead lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            lead.Email = 'test@test.com';
            lead.Email_Verification_Codes_Sent__c = ProfileController.MAX_EMAIL_VERIFICATION_CODES;
            insert lead;

            ProfileController.Profile profile = new ProfileController.Profile();
            profile.id = lead.Id;

            Boolean verificationSent = ProfileController.sendVerificationEmail(profile);

            System.assertEquals(false, verificationSent);
        }
    }

    @isTest
    static void testSendVerificationEmailException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.sendVerificationEmail(new ProfileController.Profile());
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testVerifyEmailCode() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            Lead lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            lead.Email_Verification_Code__c = '123456';
            insert lead;

            ProfileController.Profile profile = new ProfileController.Profile();
            profile.id = lead.Id;
            profile.emailCode = '123456';

            String result = ProfileController.verifyEmailCode(profile);

            System.assertEquals(Constants.VERIFICATION_RESULT_SUCCESS, result);

            Lead updatedLead = [SELECT isEmailVerified__c FROM Lead WHERE Id = :lead.Id];

            System.assertEquals(true, updatedLead.isEmailVerified__c);
        }
    }

    @isTest
    static void testVerifyEmailCodeMismatch() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            Lead lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            lead.Email_Verification_Code__c = '123456';
            insert lead;

            ProfileController.Profile profile = new ProfileController.Profile();
            profile.id = lead.Id;
            profile.emailCode = '112333';

            String result = ProfileController.verifyEmailCode(profile);

            System.assertEquals(Constants.VERIFICATION_RESULT_INCORRECT, result);

            Lead updatedLead = [SELECT isEmailVerified__c FROM Lead WHERE Id = :lead.Id];

            System.assertEquals(false, updatedLead.isEmailVerified__c);
        }
    }

    @isTest
    static void testVerifyEmailCodeAttemptsExhausted() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            Lead lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            lead.Email_Verification_Code__c = '123456';
            lead.Email_Verification_Attempts__c = ProfileController.MAX_EMAIL_VERIFICATION_ATTEMPTS;
            insert lead;

            ProfileController.Profile profile = new ProfileController.Profile();
            profile.id = lead.Id;
            profile.emailCode = '123456';

            String result = ProfileController.verifyEmailCode(profile);

            System.assertEquals(Constants.VERIFICATION_RESULT_TOO_MANY, result);

            Lead updatedLead = [SELECT isEmailVerified__c FROM Lead WHERE Id = :lead.Id];

            System.assertEquals(false, updatedLead.isEmailVerified__c);
        }
    }

    @isTest
    static void testVerifyEmailCodeAttemptsExhaustedOnFinalAttempt() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            Lead lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            lead.Email_Verification_Code__c = '123456';
            lead.Email_Verification_Attempts__c = (ProfileController.MAX_EMAIL_VERIFICATION_ATTEMPTS - 1);
            insert lead;

            ProfileController.Profile profile = new ProfileController.Profile();
            profile.id = lead.Id;
            profile.emailCode = '112333';

            String result = ProfileController.verifyEmailCode(profile);

            System.assertEquals(Constants.VERIFICATION_RESULT_TOO_MANY, result);

            Lead updatedLead = [SELECT isEmailVerified__c FROM Lead WHERE Id = :lead.Id];

            System.assertEquals(false, updatedLead.isEmailVerified__c);
        }
    }

    @isTest
    static void testVerifyEmailCodeException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.verifyEmailCode(new ProfileController.Profile());
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testSendVerificationSms() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            Lead lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            insert lead;

            ProfileController.Profile profile = new ProfileController.Profile();
            profile.id = lead.Id;

            Boolean verificationSent = ProfileController.sendVerificationSms(profile);

            System.assertEquals(true, verificationSent);

            Lead updatedLead = [SELECT SMS_Verification_Codes_Sent__c, SMS_Verification_Code__c, SMS_Verification_Attempts__c FROM Lead WHERE Id = :lead.Id];

            System.assertEquals(1, updatedLead.SMS_Verification_Codes_Sent__c);
            System.assert(String.isNotBlank(updatedLead.SMS_Verification_Code__c));
            System.assertEquals(0, updatedLead.SMS_Verification_Attempts__c);
        }
    }

    @isTest
    static void testSendVerificationSmsCodesExhausted() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            Lead lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            lead.SMS_Verification_Codes_Sent__c = ProfileController.MAX_SMS_VERIFICATION_CODES;
            insert lead;

            ProfileController.Profile profile = new ProfileController.Profile();
            profile.id = lead.Id;

            Boolean verificationSent = ProfileController.sendVerificationSms(profile);

            System.assertEquals(false, verificationSent);
        }
    }

    @isTest
    static void testSendVerificationSmsException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.sendVerificationSms(new ProfileController.Profile());
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testVerifySmsCode() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            Lead lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            lead.SMS_Verification_Code__c = '123456';
            insert lead;

            ProfileController.Profile profile = new ProfileController.Profile();
            profile.id = lead.Id;
            profile.smsCode = '123456';

            String result = ProfileController.verifySmsCode(profile);

            System.assertEquals(Constants.VERIFICATION_RESULT_SUCCESS, result);

            Lead updatedLead = [SELECT isSMSVerified__c FROM Lead WHERE Id = :lead.Id];

            System.assertEquals(true, updatedLead.isSMSVerified__c);
        }
    }

    @isTest
    static void testVerifySmsCodeMismatch() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            Lead lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            lead.SMS_Verification_Code__c = '123456';
            insert lead;

            ProfileController.Profile profile = new ProfileController.Profile();
            profile.id = lead.Id;
            profile.smsCode = '112333';

            String result = ProfileController.verifySmsCode(profile);

            System.assertEquals(Constants.VERIFICATION_RESULT_INCORRECT, result);

            Lead updatedLead = [SELECT isSMSVerified__c FROM Lead WHERE Id = :lead.Id];

            System.assertEquals(false, updatedLead.isSMSVerified__c);
        }
    }

    @isTest
    static void testVerifySmsCodeAttemptsExhausted() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            Lead lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            lead.SMS_Verification_Code__c = '123456';
            lead.SMS_Verification_Attempts__c = ProfileController.MAX_SMS_VERIFICATION_ATTEMPTS;
            insert lead;

            ProfileController.Profile profile = new ProfileController.Profile();
            profile.id = lead.Id;
            profile.smsCode = '123456';

            String result = ProfileController.verifySmsCode(profile);

            System.assertEquals(Constants.VERIFICATION_RESULT_TOO_MANY, result);

            Lead updatedLead = [SELECT isSMSVerified__c FROM Lead WHERE Id = :lead.Id];

            System.assertEquals(false, updatedLead.isSMSVerified__c);
        }
    }

    @isTest
    static void testVerifySmsCodeAttemptsExhaustedOnFinalAttempt() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            Lead lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            lead.SMS_Verification_Code__c = '123456';
            lead.SMS_Verification_Attempts__c = ProfileController.MAX_SMS_VERIFICATION_ATTEMPTS - 1;
            insert lead;

            ProfileController.Profile profile = new ProfileController.Profile();
            profile.id = lead.Id;
            profile.emailCode = '112333';

            String result = ProfileController.verifySmsCode(profile);

            System.assertEquals(Constants.VERIFICATION_RESULT_TOO_MANY, result);

            Lead updatedLead = [SELECT isSMSVerified__c FROM Lead WHERE Id = :lead.Id];

            System.assertEquals(false, updatedLead.isSMSVerified__c);
        }
    }

    @isTest
    static void testVerifySmsCodeException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.verifySmsCode(new ProfileController.Profile());
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testCreateUser() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            Level__c level = new Level__c();
            level.Donation_Threshold__c = 0;
            insert level;

            Account account = TestUtil.createMiramarCenter();
            insert account;

            Lead lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            insert lead;

            ProfileController.Profile profile = new ProfileController.Profile();
            profile.id = lead.Id;
            profile.centerId = account.Id;
            profile.nickname = 'testnick';
            profile.language = 'en_US';

            Id userId = ProfileController.createUser(profile);

            Account personAccount = [
                SELECT ID,
                        First_Visit_Code__c
                FROM Account 
                WHERE Name = 'Test First Test Last' 
            ];

            system.assertEquals(7, personAccount.First_Visit_Code__c.length());

            // Site.createExternalUser() doesn't work in unit tests so the user isn't
            // actually created and the following assertions won't work.
            /*
                User user = [
                    SELECT
                        FirstName, LastName
                    FROM
                        User
                    WHERE
                        Name = 'Test First Test Last'
                ];

                System.assertEquals('First', user.FirstName);
                System.assertEquals('Last', user.LastName);
            */
        }
    }

    
    @isTest
    static void testCreateUserException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.createUser(new ProfileController.Profile());
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testSetupUser() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createExperienceGuestUser()) {
            ProfileController.Profile profile = new ProfileController.Profile();
            profile.userId = experienceUser.Id;

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new CalloutMock(''));

            ProfileController.setupUser(profile);

            Test.stopTest();

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
    static void testSetupUserException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.setupUser(new ProfileController.Profile());
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testDeactivateUser() {
        System.runAs(TestUtil.createAdminUser()) {
            User experienceUser = TestUtil.createExperienceUser();

            System.assertEquals(true, [SELECT IsActive FROM User WHERE Id = :experienceUser.Id].IsActive);

            ProfileController.deactivateUser(experienceUser.Id);

            System.assertEquals(false, [SELECT IsActive FROM User WHERE Id = :experienceUser.Id].IsActive);
        }
    }

    @isTest
    static void testDeactivateUserException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.deactivateUser(UserInfo.getUserId());
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testCreateUserFromScheduler() {
        Id accountId;

        System.runAs(TestUtil.createAdminUser()) {
            Level__c level = new Level__c();
            level.Donation_Threshold__c = 0;
            insert level;

            Account account = TestUtil.createMiramarCenter();
            insert account;

            Lead lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            lead.Email = 'ctester@ccurrents.com.testing';
            insert lead;

            ProfileController.Profile profile = new ProfileController.Profile();
            profile.id = lead.Id;
            profile.centerId = account.Id;
            profile.nickname = 'testnick';
            profile.language = 'en_US';

            Test.startTest();
            accountId = ProfileController.createUserFromScheduler(profile);
            Test.stopTest();
        }

        Assert.areEqual(1, [SELECT count() FROM Account WHERE Id = :accountId], 'A Valid account id should have been created and returned');

        User targetUserRecord = [SELECT Id, Email, FirstName, LastName FROM User WHERE AccountId = :accountId LIMIT 1];
        Assert.isNotNull(targetUserRecord, 'A user record linked to the returned account should have been created');
        Assert.areEqual('ctester@ccurrents.com.testing', targetUserRecord.Email, 'The user\'s email should have be set to ctester@ccurrents.com.testing');
        Assert.areEqual('Test First', targetUserRecord.FirstName, 'The user\'s first name should have be set to Test First');
        Assert.areEqual('Test Last', targetUserRecord.LastName, 'The user\'s last name should have be set to Test Last');
    }

    @isTest 
    static void testCreateUserFromSchedulerException() {
        TestUtil.throwException = true;
        Boolean exceptionThrown = false;

        try {
            ProfileController.createUserFromScheduler(new ProfileController.Profile());
        } catch (Exception e) {
            exceptionThrown = true;
        }

        Assert.isTrue(exceptionThrown, 'An exception should have been thrown');
    }

}