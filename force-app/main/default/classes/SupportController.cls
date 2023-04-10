public with sharing class SupportController {
    @AuraEnabled
    public static void createSupportCaseForUser(String message) {
        Account targetDonorAccount = [SELECT Id, PersonContactId FROM Account WHERE Id IN (Select AccountId FROM User WHERE Id = :UserInfo.getUserId()) LIMIT 1];
        List<Group> customerSupportQueue;

        try {
            customerSupportQueue = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperNAME = 'Customer_Support' LIMIT 1];
        } catch(QueryException e) {
            throw new AuraHandledException('We couldn\'t assign your request to customer support at this time. Please try again later.');
        }        

        try {
            Case baseCase = new Case(
                Subject = Constants.DEFAULT_CUSTOMER_SUPPORT_CASE_SUBJECT,
                Origin = Constants.DEFAULT_CUSTOMER_SUPPORT_CASE_ORIGIN,
                Reason = Constants.DEFAULT_CUSTOMER_SUPPORT_CASE_REASON,
                ContactId = targetDonorAccount.PersonContactId,
                AccountId = targetDonorAccount.Id,
                Description = message
            );

            if (customerSupportQueue != null && customerSupportQueue.size() > 0) {
                baseCase.OwnerId = customerSupportQueue[0].Id;
            }

            insert baseCase;
        } catch(DmlException e) {
            throw new AuraHandledException('We couldn\'t create your support request at this time. Please try again later.');
        }
    }

    @AuraEnabled
    public static ContactInformation fetchSupportContactInformation() {
        return new ContactInformation(Support_Contact_Information__c.getOrgDefaults());
    }

    public class ContactInformation {
        @AuraEnabled 
        public String contactEmail;
        @AuraEnabled
        public String contactPhone;

        public ContactInformation(Support_Contact_Information__c contactInformation) {
            this.contactEmail = contactInformation.Contact_Email__c;
            this.contactPhone = contactInformation.Contact_Phone__c;
        }
    }
}