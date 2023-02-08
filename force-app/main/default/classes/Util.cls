public with sharing class Util {

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