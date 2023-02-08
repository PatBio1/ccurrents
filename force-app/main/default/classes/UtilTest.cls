@isTest
public with sharing class UtilTest {

    @isTest
    static void testCreateAuraHandledException() {
        AuraHandledException ahe = Util.createAuraHandledException(new TestUtil.TestException('Test'));

        System.assert(ahe.getMessage().contains('Test'));
    }

}