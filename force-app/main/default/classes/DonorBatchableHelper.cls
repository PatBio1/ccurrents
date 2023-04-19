public with sharing class DonorBatchableHelper {
    public static Map<Id, Integer> calculateDonor365DayVisitTotals(List<Contact> contacts) {
        Map<Id, Integer> donorIdToVisitCount = new Map<Id, Integer>();
        
        for(AggregateResult donorVistAgg : [
            SELECT count(Id) visitCount, Donor__c donor
            FROM Visit__c
            WHERE Appointment_Datetime__c = LAST_N_DAYS:365 AND 
                Status__c = 'Complete' AND 
                Outcome__c = 'Donation' 
            GROUP BY Donor__c
        ]) {
            donorIdToVisitCount.put((Id)donorVistAgg.get('donor'), (Integer)donorVistAgg.get('visitCount'));
        }

        return donorIdToVisitCount;
    }
}