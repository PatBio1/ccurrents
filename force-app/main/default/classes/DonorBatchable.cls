public with sharing class DonorBatchable implements Database.Batchable<SObject>, Schedulable {
    public void execute(SchedulableContext sc) {
		Database.executeBatch(new DonorBatchable(), 200);
	}

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([SELECT Id, Total_Visits_365d__c, Loyalty_Level__c FROM Contact]);
    }

    public void execute(Database.BatchableContext context, List<Contact> donors) {
		processDonorTotalVisits(donors);
	}

	public void finish(Database.BatchableContext context) {

	}

    public void processDonorTotalVisits(List<Contact> donors) {
        Map<Id, Integer> donorIdToVisitCount = DonorBatchableHelper.calculateDonor365DayVisitTotals(donors);
        List<Level__c> activeLevels = [SELECT Id, Donation_Threshold__c FROM Level__c WHERE isActive__c = true AND isVisible__c = true ORDER BY Donation_Threshold__c ASC];

        for (Contact donor : donors) {
            donor.Total_Visits_365d__c = donorIdToVisitCount.get(donor.Id);

            for(Level__c level : activeLevels) {
                if (donor.Total_Visits_365d__c >= level.Donation_Threshold__c) {
                    donor.Loyalty_Level__c = level.Id;
                } else {
                    // Given the list is sorted, we can break out of the loop once we find the first level that the donor doesn't qualify for
                    break;
                }
            }
        }

        update donors;
    }
}