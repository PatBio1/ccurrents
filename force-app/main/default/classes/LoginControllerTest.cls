@isTest
public with sharing class LoginControllerTest {

    @isTest
    static void testLogin() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            String startUrl = LoginController.login('user', 'pass', '/');

            System.assertEquals(null, startUrl);
        }
    }

    @isTest
    static void testLoginException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                LoginController.login('user', 'pass', '/');
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testSendVerificationEmail() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean verificationSent = LoginController.sendVerificationEmail(experienceUser.Email);

            System.assertEquals(true, verificationSent);

            User updatedExperienceUser = [SELECT Verification_Code__c, Verification_Attempts__c FROM User WHERE Id = :experienceUser.Id];

            System.assert(String.isNotBlank(updatedExperienceUser.Verification_Code__c));
            System.assertEquals(0, updatedExperienceUser.Verification_Attempts__c);
        }
    }

    @isTest
    static void testSendVerificationEmailUsernameNotFound() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            String invalidUsername = 'nonexistent@' + UserInfo.getOrganizationId() + '.com';

            Boolean verificationSent = LoginController.sendVerificationEmail(invalidUsername);

            System.assertEquals(false, verificationSent);
        }
    }

    @isTest
    static void testSendVerificationEmailException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                LoginController.sendVerificationEmail('test@test.com');
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testVerifyEmailCode() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createExperienceGuestUser()) {
            experienceUser.Verification_Code__c = '123456';
            update experienceUser;

            String result = LoginController.verifyEmailCode(experienceUser.Email, '123456');

            System.assertEquals(Constants.VERIFICATION_RESULT_SUCCESS, result);
        }
    }

    @isTest
    static void testVerifyEmailCodeUsernameNotFound() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            String invalidUsername = 'nonexistent@' + UserInfo.getOrganizationId() + '.com';

            String result = LoginController.verifyEmailCode(invalidUsername, '112333');

            System.assertEquals(Constants.VERIFICATION_RESULT_INCORRECT, result);
        }
    }

    @isTest
    static void testVerifyEmailCodeMismatch() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createExperienceGuestUser()) {
            experienceUser.Verification_Code__c = '123456';
            update experienceUser;

            String result = LoginController.verifyEmailCode(experienceUser.Email, '112333');

            System.assertEquals(Constants.VERIFICATION_RESULT_INCORRECT, result);
        }
    }

    @isTest
    static void testVerifyEmailCodeAttemptsExhausted() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createExperienceGuestUser()) {
            experienceUser.Verification_Code__c = '123456';
            experienceUser.Verification_Attempts__c = LoginController.MAX_VERIFICATION_ATTEMPTS;
            update experienceUser;

            String result = LoginController.verifyEmailCode(experienceUser.Email, '123456');

            System.assertEquals(Constants.VERIFICATION_RESULT_TOO_MANY, result);
        }
    }

    @isTest
    static void testVerifyEmailCodeException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                LoginController.verifyEmailCode('test@test.com', '123456');
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

}