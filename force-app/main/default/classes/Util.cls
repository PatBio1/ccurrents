public with sharing class Util {

    public static String generateVerificationCode() {
        String verificationCode = '';

        // 6 digits long.
        for (Integer i = 0; i < 6; i++) {
            // Only digits 1 - 9 so that "o" and zero don't get confused.
            Double digit = Math.floor(Math.random() * 9) + 1;
            verificationCode += digit.intValue();
        }

        return verificationCode;
    }

    public static Id getOrgWideEmailAddress(String displayName) {
        return (Test.isRunningTest() ? null : [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = :displayName].Id);
    }

    public static AuraHandledException createAuraHandledException(Exception e) {
        String message = e.getMessage() + ' -- ' + e.getStackTraceString();

        AuraHandledException ahe = new AuraHandledException(message);
        ahe.setMessage(message);
        return ahe;
    }

    public static void testExceptionHandling() {
        if (TestUtil.throwException) {
            throw new TestUtil.TestException();
        }
    }

}