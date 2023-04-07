public without sharing class LoginController {

    public static final Integer MAX_VERIFICATION_ATTEMPTS = 3;
    public static final Integer DEFAULT_VERIFICATION_TIMEOUT_MINUTES = 5;

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

            List<User> users = [SELECT ContactId FROM User WHERE Username = :username];

            if (users.size() > 0) {
                Contact contact = new Contact();
                contact.Id = users[0].ContactId;
                contact.Verification_Code__c = Util.generateVerificationCode();
                contact.Verification_Code_Time__c = DateTime.now();
                contact.Verification_Attempts__c = 0;
                update contact;

                Id orgWideEmailId = Util.getOrgWideEmailAddress(Constants.ORG_WIDE_EMAIL_NAME);

                Id forgotPasswordTemplateId = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Forgot_Password'].Id;

                Messaging.SingleEmailMessage emailMessage = new Messaging.SingleEmailMessage();
                emailMessage.setOrgWideEmailAddressId(orgWideEmailId);
                emailMessage.setTemplateId(forgotPasswordTemplateId);
                emailMessage.setTargetObjectId(contact.Id);
    
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

            List<User> users = [SELECT ContactId FROM User WHERE Username = :username];

            if (users.size() > 0) {
                Contact contact = [SELECT Verification_Code__c, Verification_Code_Time__c, Verification_Attempts__c FROM Contact WHERE Id = :users[0].ContactId];

                Integer verificationAttempts = (contact.Verification_Attempts__c == null ? 0 : contact.Verification_Attempts__c.intValue());

                if (verificationAttempts < MAX_VERIFICATION_ATTEMPTS) {
                    if (code == contact.Verification_Code__c) {
                        Proesis_Settings__c proesisSettings = Proesis_Settings__c.getOrgDefaults();
                        Integer timeoutMinutes = (proesisSettings?.Verification_Timeout_Minutes__c == null ? DEFAULT_VERIFICATION_TIMEOUT_MINUTES : proesisSettings?.Verification_Timeout_Minutes__c.intValue());

                        if (contact.Verification_Code_Time__c.addMinutes(timeoutMinutes) > DateTime.now()) {
                            return Constants.VERIFICATION_RESULT_SUCCESS;
                        } else {
                            return Constants.VERIFICATION_RESULT_TIMED_OUT;
                        }
                        
                    } else {
                        contact.Verification_Attempts__c = verificationAttempts + 1;
                        update contact;

                        if (contact.Verification_Attempts__c < MAX_VERIFICATION_ATTEMPTS) {
                            return Constants.VERIFICATION_RESULT_INCORRECT;
                        } else {
                            return Constants.VERIFICATION_RESULT_TOO_MANY;
                        }
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

    @AuraEnabled
    public static Boolean setPassword(String username, String password) {
        try {
            Util.testExceptionHandling();

            username = username + Constants.USERNAME_SUFFIX;

            List<User> users = [SELECT Id FROM User WHERE Username = :username];

            if (users.size() > 0) {
                System.setPassword(users[0].Id, password);

                return true;
            } else {
                return false;
            }
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

}