public with sharing class DonorBatchable implements Database.Batchable<SObject>, Schedulable {
    public void execute(SchedulableContext sc) {
		Database.executeBatch(new DonorBatchable(), 200);
	}

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([SELECT Id, Total_Visits_365d__c FROM Contact]);
    }

    public void execute(Database.BatchableContext context, List<Contact> donors) {
		processDonorTotalVisits(donors);
	}

	public void finish(Database.BatchableContext context) {

	}

    public void processDonorTotalVisits(List<Contact> donors) {
        Map<Id, Integer> donorIdToVisitCount = DonorBatchableHelper.calculateDonor365DayVisitTotals(donors);

        for (Contact donor : donors) {
            donor.Total_Visits_365d__c = donorIdToVisitCount.get(donor.Id);
        }

        update donors;
    }
}