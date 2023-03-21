/**
 * Created by joshlequire1 on 3/10/23.
 */

public without sharing class VisitSelector {

    public static List<Visit__c> getVisitsInRangeForDonorNumbers(List<Datetime> dateTimesToProcess, Set<String> donorNumbersToQuery){
        dateTimesToProcess.sort();
        // Assuming FDA 48 Hour rule mandates (at least) 24 hours between visits
        Datetime minDateTime = dateTimesToProcess[0].addHours(-12);
        Datetime maxDateTime = dateTimesToProcess[dateTimesToProcess.size() - 1].addHours(12);

        List<Visit__c> results = [SELECT Id, Status__c, Appointment__r.Datetime__c, Donor__c, Donor__r.AccountId, Donor__r.Account.DonorId__c FROM Visit__c WHERE Donor__r.Account.DonorId__c IN :donorNumbersToQuery AND Appointment__r.Datetime__c >= :minDateTime AND Appointment__r.Datetime__c <= :maxDateTime];

        return results;
    }

    public static List<Visit__c> getVisitsInDateRange(Date startDate, Date endDate){
        Datetime scheduleStart = Datetime.newInstance(startDate, Time.newInstance(0,0,0,0));
        Datetime scheduleEnd = Datetime.newInstance(endDate, Time.newInstance(23,59,59,0));
        List<Visit__c> results = [SELECT Id, Donor__c, Status__c, Appointment__r.Datetime__c FROM Visit__c WHERE Appointment__r.Datetime__c >= :scheduleStart AND Appointment__r.Datetime__c <= :scheduleEnd];

        return results;
    }

}