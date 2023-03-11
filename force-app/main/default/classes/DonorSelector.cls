public with sharing class DonorSelector {
    @AuraEnabled
    public static List<Account> searchVisitElgibleDonorByName(String nameSearchString, DateTime targetVisitDateString) {
        if (String.isEmpty(nameSearchString)) {
            return null;
        }
        
        return [
            SELECT Id, Name, PersonEmail, PersonMobilePhone, Soonest_Next_Visit__pc
            FROM Account
            WHERE Name LIKE :(nameSearchString + '%') AND 
                RecordTypeId = :Schema.SObjectType.Account.getRecordTypeInfosByName().get('Donor').getRecordTypeId() AND 
                Soonest_Next_Visit__pc <= :targetVisitDateString
        ];
    }
}