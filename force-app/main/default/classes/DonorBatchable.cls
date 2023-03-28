public with sharing class DonorBatchable implements Database.Batchable<SObject>, Schedulable {
    public void execute(SchedulableContext sc) {
		Database.executeBatch(new DonorBatchable(), 200);
	}

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id, Total_Visits_365d__c, (
                SELECT Id, Appointment_Datetime__c
                FROM Visits__r
                WHERE Appointment_Datetime__c >= LAST_N_DAYS:365 AND 
                    Status__c = 'Complete' AND 
                    Outcome__c = 'Donation'
            )
            FROM Contact
        ]);
    }

    public void execute(Database.BatchableContext context, List<Contact> donors) {
		processDonorTotalVisits(donors);
	}

	public void finish(Database.BatchableContext context) {

	}

    public void processDonorTotalVisits(List<Contact> donors) {
        for (Contact donor : donors) {
            donor.Total_Visits_365d__c = donor.Visits__r.size();
        }
        update donors;
    }
}