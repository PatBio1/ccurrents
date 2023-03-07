public without sharing class LoginController {

    @AuraEnabled
    public static String login(String username, String password) {
        try {
            Util.testExceptionHandling();

            username = username + Constants.USERNAME_SUFFIX;

            ApexPages.PageReference startPage = Site.login(username, password, null);//'/ProesisDonor/apex/CommunitiesLanding');

            return startPage?.getUrl();
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

}