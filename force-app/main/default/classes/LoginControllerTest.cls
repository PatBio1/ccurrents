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

}