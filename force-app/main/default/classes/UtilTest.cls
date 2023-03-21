@isTest
public with sharing class UtilTest {

    @isTest
    static void testGenerateVerificationCode() {
        String verificationCode = Util.generateVerificationCode();

        System.assertNotEquals(null, verificationCode);
        System.assertEquals(6, verificationCode.length());
        System.assert(verificationCode.containsOnly('123456789'));
    }


    @isTest
    static void testCreateAuraHandledException() {
        AuraHandledException ahe = Util.createAuraHandledException(new TestUtil.TestException('Test'));

        System.assert(ahe.getMessage().contains('Test'));
    }

}