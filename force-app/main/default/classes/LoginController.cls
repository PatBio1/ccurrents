public without sharing class LoginController {

    public static final Integer MAX_VERIFICATION_ATTEMPTS = 3;

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

    @AuraEnabled
    public static Boolean sendVerificationEmail(String username) {
        try {
            Util.testExceptionHandling();

            username = username + Constants.USERNAME_SUFFIX;

            List<User> users = [SELECT Id FROM User WHERE Username = :username];

            if (users.size() > 0) {
                users[0].Verification_Code__c = Util.generateVerificationCode();
                users[0].Verification_Attempts__c = 0;
                update users[0];

                Id orgWideEmailId = Util.getOrgWideEmailAddress(Constants.ORG_WIDE_EMAIL_NAME);

                Id forgotPasswordTemplateId = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Forgot_Password'].Id;

                Messaging.SingleEmailMessage emailMessage = new Messaging.SingleEmailMessage();
                emailMessage.setOrgWideEmailAddressId(orgWideEmailId);
                emailMessage.setTemplateId(forgotPasswordTemplateId);
                emailMessage.setTargetObjectId(users[0].Id);
                emailMessage.setSaveAsActivity(false);
    
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{emailMessage});

                return true;
            } else {
                return false;
            }
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static String verifyEmailCode(String username, String code) {
        try {
            Util.testExceptionHandling();

            username = username + Constants.USERNAME_SUFFIX;

            List<User> users = [SELECT Verification_Code__c, Verification_Attempts__c FROM User WHERE Username = :username];

            if (users.size() > 0) {
                User user = users[0];

                Integer verificationAttempts = (user.Verification_Attempts__c == null ? 0 : user.Verification_Attempts__c.intValue());

                if (verificationAttempts < MAX_VERIFICATION_ATTEMPTS) {
                    if (code == user.Verification_Code__c) {
                        return Constants.VERIFICATION_RESULT_SUCCESS;
                    } else {
                        user.Verification_Attempts__c = verificationAttempts + 1;
                        update user;

                        return Constants.VERIFICATION_RESULT_INCORRECT;
                    }
                } else {
                    return Constants.VERIFICATION_RESULT_TOO_MANY;
                }
            } else {
                return Constants.VERIFICATION_RESULT_INCORRECT;
            }
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

}