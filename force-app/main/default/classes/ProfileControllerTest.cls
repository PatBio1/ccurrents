@isTest
public with sharing class ProfileControllerTest {

    @isTest
    static void testGetDonorUser() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createExperienceGuestUser()) {
            ProfileController.Profile profile = new ProfileController.Profile();
            profile.email = experienceUser.Email;

            ProfileController.Donor donor = ProfileController.getDonor(profile);

            System.assertNotEquals(null, donor);
            System.assertEquals('User', donor.type);
            System.assertEquals(experienceUser.Id, donor.id);
        }
    }

    @isTest
    static void testGetDonorLead() {
        Lead lead;

        System.runAs(TestUtil.createAdminUser()) {
            lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            lead.Email = 'donor@test.com';
            insert lead;
        }

        System.runAs(TestUtil.createExperienceGuestUser()) {
            ProfileController.Profile profile = new ProfileController.Profile();
            profile.email = lead.Email;

            ProfileController.Donor donor = ProfileController.getDonor(profile);

            System.assertNotEquals(null, donor);
            System.assertEquals('Lead', donor.type);
            System.assertEquals(lead.Id, donor.id);
        }
    }

    @isTest
    static void testGetDonorNotFound() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            ProfileController.Profile profile = new ProfileController.Profile();
            profile.email = 'donor@test.com';

            ProfileController.Donor donor = ProfileController.getDonor(profile);

            System.assertEquals(null, donor);
        }
    }

    @isTest
    static void testGetDonorException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.getDonor(new ProfileController.Profile());
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testGetLead() {
        Lead lead;

        System.runAs(TestUtil.createAdminUser()) {
            lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            lead.Street = '123 Main Steet';
            lead.Street_Line_2__c = 'Apt 100';
            lead.City = 'Atlanta';
            lead.State = 'GA';
            lead.PostalCode = '30327';
            lead.How_will_you_get_to_the_Center__c = 'Car';
            lead.Preferred_Name__c = 'nickname';
            insert lead;
        }

        System.runAs(TestUtil.createExperienceGuestUser()) {
            ProfileController.Profile profile = ProfileController.getLead(lead.Id);

            System.assertEquals('123 Main Steet', profile.street);
            System.assertEquals('Apt 100', profile.street2);
            System.assertEquals('Atlanta', profile.city);
            System.assertEquals('GA', profile.state);
            System.assertEquals('30327', profile.postalCode);
            System.assertEquals('Car', profile.howGetToCenter);
            System.assertEquals('nickname', profile.nickname);
        }
    }

    @isTest
    static void testGetLeadException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.getLead(null);
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

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
    static void testSmsVerificationEnabled() {
        User guestUser = TestUtil.createExperienceGuestUser();

        System.runAs(guestUser) {
            Boolean enabled = ProfileController.smsVerificationEnabled();

            System.assertEquals(false, enabled);
        }
        
        System.runAs(TestUtil.createAdminUser()) {
            Proesis_Settings__c proesisSettings = Proesis_Settings__c.getOrgDefaults();
            proesisSettings.SMS_Verification_Enabled__c = true;
            upsert proesisSettings;
        }

        System.runAs(guestUser) {
            Boolean enabled = ProfileController.smsVerificationEnabled();

            System.assertEquals(true, enabled);
        }
    }

    @isTest
    static void testSmsVerificationEnabledException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.smsVerificationEnabled();
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
            level.isActive__c = true;
            level.isVisible__c = true;
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
                SELECT
                    First_Visit_Code__c
                FROM
                    Account
                WHERE
                    Name = 'Test First Test Last'
            ];

            System.assertEquals(7, personAccount.First_Visit_Code__c.length());

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
    static void testGetProfile() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createAdminUser()) {
            Account center = TestUtil.createMiramarCenter();
            insert center;

            AccountContactRelation accountContactRelation = new AccountContactRelation();
            accountContactRelation.AccountId = center.Id;
            accountContactRelation.ContactId = experienceUser.ContactId;
            accountContactRelation.Roles = 'Donor';
            insert accountContactRelation;
        }

        System.runAs(experienceUser) {
            ProfileController.Profile profile = ProfileController.getProfile();

            System.assertEquals(experienceUser.FirstName, profile.firstName);
            System.assertEquals(experienceUser.LastName, profile.lastName);
        }
    }

    @isTest
    static void testGetProfileException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.getProfile();
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testChangeProfile() {
        User experienceUser = TestUtil.createExperienceUser();
        Visit__c visit;

        System.runAs(TestUtil.createAdminUser()) {
            Account center = TestUtil.createMiramarCenter();
            insert center;

            AccountContactRelation accountContactRelation = new AccountContactRelation();
            accountContactRelation.AccountId = center.Id;
            accountContactRelation.ContactId = experienceUser.ContactId;
            accountContactRelation.Roles = 'Donor';
            insert accountContactRelation;

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = Date.today().addDays(-10),
                End_Date__c = Date.today().addDays(30)
            );
            insert schedule;

            Appointment__c appointment = new Appointment__c();
            appointment.Schedule__c = schedule.Id;
            appointment.Datetime__c = DateTime.now().addDays(1);
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

            visit = new Visit__c();
            visit.Appointment__c = appointment.Id;
            visit.Donor__c = experienceUser.ContactId;
            visit.Status__c = 'Scheduled';
            visit.Center_Donation_Type__c = centerDonationType.Id;
            insert visit;
        }

        System.runAs(experienceUser) {
            ProfileController.Profile profile = new ProfileController.Profile();
            
            ProfileController.changeProfile(profile);

            List<Task> tasks = [SELECT Subject FROM Task WHERE WhoId = :experienceUser.ContactId AND WhatId = :visit.Id];

            System.assertEquals(1, tasks.size());
            System.assertEquals('Information Change', tasks[0].Subject);
        }
    }

    @isTest
    static void testChangeProfileException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.changeProfile(new ProfileController.Profile());
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testDeactivateUser() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createAdminUser()) {
            System.assertEquals(true, [SELECT IsActive FROM User WHERE Id = :experienceUser.Id].IsActive);

            Account center = TestUtil.createMiramarCenter();
            insert center;

            Donation_Type__c donationType = new Donation_Type__c();
            insert donationType;

            Center_Donation_Type__c centerDonationType = new Center_Donation_Type__c();
            centerDonationType.Center__c = center.Id;
            centerDonationType.Donation_Type__c = donationType.Id;
            centerDonationType.isActive__c = true;
            insert centerDonationType;

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = Date.today().addDays(-10),
                End_Date__c = Date.today().addDays(30)
            );
            insert schedule;

            Appointment__c pastAppointment = new Appointment__c();
            pastAppointment.Schedule__c = schedule.Id;
            pastAppointment.Datetime__c = DateTime.now().addDays(-1);
            pastAppointment.Duration__c = 10;
            pastAppointment.Capacity__c = 5;

            Appointment__c futureAppointment = new Appointment__c();
            futureAppointment.Schedule__c = schedule.Id;
            futureAppointment.Datetime__c = DateTime.now().addDays(1);
            futureAppointment.Duration__c = 10;
            futureAppointment.Capacity__c = 5;

            insert new List<Appointment__c>{pastAppointment, futureAppointment};

            Visit__c pastVisit = new Visit__c();
            pastVisit.Appointment__c = pastAppointment.Id;
            pastVisit.Donor__c = experienceUser.ContactId;
            pastVisit.Status__c = 'Scheduled';
            pastVisit.Center_Donation_Type__c = centerDonationType.Id;

            Visit__c futureVisit = new Visit__c();
            futureVisit.Appointment__c = futureAppointment.Id;
            futureVisit.Donor__c = experienceUser.ContactId;
            futureVisit.Status__c = 'Scheduled';
            futureVisit.Center_Donation_Type__c = centerDonationType.Id;

            insert new List<Visit__c>{pastVisit, futureVisit};

            Test.startTest();

            ProfileController.deactivateUser(experienceUser.Id);

            Test.stopTest();

            // Validate user was deactivated.
            System.assertEquals(false, [SELECT IsActive FROM User WHERE Id = :experienceUser.Id].IsActive);

            // Validate past visit wasn't modified.
            System.assertEquals('Scheduled', [SELECT Status__c FROM Visit__c WHERE Id = :pastVisit.Id].Status__c);

            // Validate future visit was canceled.
            Visit__c updatedFutureVisit = [SELECT Status__c, Outcome__c FROM Visit__c WHERE Id = :futureVisit.Id];

            System.assertEquals('Complete', updatedFutureVisit.Status__c);
            System.assertEquals('Canceled', updatedFutureVisit.Outcome__c);
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
        Id expectedLastUsedCenterId;

        System.runAs(TestUtil.createAdminUser()) {
            Level__c level = new Level__c();
            level.Donation_Threshold__c = 0;
            level.isActive__c = true;
            level.isVisible__c = true;
            insert level;

            Account account = TestUtil.createMiramarCenter();
            insert account;

            expectedLastUsedCenterId = account.Id;

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
            profile.street = '123 Test St';
            profile.city = 'Test City';
            profile.state = 'Test State';
            profile.postalCode = '12345';

            Test.startTest();
            accountId = ProfileController.createUserFromScheduler(profile);
            Test.stopTest();
        }

        Account createdAccount = [SELECT Id, Last_Used_Center__pc, PersonMailingStreet, PersonMailingCity, PersonMailingState, PersonMailingPostalCode, PersonMailingCountry FROM Account WHERE Id = :accountId LIMIT 1];
        Assert.isNotNull(createdAccount, 'A Valid account id should have been created and returned');
        Assert.areEqual(expectedLastUsedCenterId, createdAccount.Last_Used_Center__pc, 'The account\'s last used center should have been set to the center id passed in');
        Assert.areEqual('123 Test St', createdAccount.PersonMailingStreet, 'The account\'s mailing street should have been set to 123 Test St');
        Assert.areEqual('Test City', createdAccount.PersonMailingCity, 'The account\'s mailing city should have been set to Test City');
        Assert.areEqual('Test State', createdAccount.PersonMailingState, 'The account\'s mailing state should have been set to Test State');
        Assert.areEqual('12345', createdAccount.PersonMailingPostalCode, 'The account\'s mailing postal code should have been set to 12345');
        Assert.areEqual('US', createdAccount.PersonMailingCountry, 'The account\'s mailing country should have been set to US');

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

    @isTest 
    static void testHandleCreateMarketingConsent() {
        Lead lead = new Lead();
        lead.FirstName = 'Test Lead First';
        lead.LastName = 'Test Last';
        lead.Email = 'ctester@ccurrents.com.testing';
        insert lead;

        Account testDonorAccount = TestUtil.createDonor('111-222');
        insert testDonorAccount;

        Contact testDonor = [SELECT Id FROM Contact WHERE AccountId = :testDonorAccount.Id LIMIT 1];

        Test.startTest();
        ProfileController.handleCreateMarketingConsent(lead.Id, testDonor.Id);
        Test.stopTest();

        List<Consent_Transaction__c> marketingConsents = [
            SELECT Id, Scope__c, Source__c, Type_of_Consent__c 
            FROM Consent_Transaction__c 
            WHERE Lead__c = :lead.Id AND 
                Contact__c = :testDonor.Id
        ];

        Assert.areEqual(1, marketingConsents.size(), 'A marketing consent should have been created');
        Assert.areEqual(Constants.DEFAULT_MARKETING_CONSENT_SCOPE, marketingConsents[0].Scope__c, 'The marketing consent\'s scope should be ' + Constants.DEFAULT_MARKETING_CONSENT_SCOPE);
        Assert.areEqual(Constants.DEFAULT_MARKETING_CONSENT_SOURCE, marketingConsents[0].Source__c, 'The marketing consent\'s source should be ' + Constants.DEFAULT_MARKETING_CONSENT_SOURCE);
        Assert.areEqual(Constants.DEFAULT_MARKETING_CONSENT_TYPE, marketingConsents[0].Type_of_Consent__c, 'The marketing consent\'s type should be ' + Constants.DEFAULT_MARKETING_CONSENT_TYPE);
    }

}