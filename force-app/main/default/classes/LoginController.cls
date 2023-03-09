public without sharing class LoginController {

    @AuraEnabled
    public static String login(String username, String password, String startUrl) {
        try {
            Util.testExceptionHandling();

            username = username + Constants.USERNAME_SUFFIX;

            ApexPages.PageReference startPage = Site.login(username, password, startUrl);

            return startPage?.getUrl();
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

}