/**
 * Created by joshlequire1 on 3/7/23.
 */

public without sharing class DonorCheckinInvocable {
    // NOTE - this assumes we'll receive a call for each unique checkin event at the Donor_CheckIn__e endpoint, but is bulkfied in case there is a need for processing these in larger batches. However, this method assumes only 1 check in per Donor Number - if multiple checkinis for the same donor are needed with this call, we'll need to refactor the method to handle this.
    @InvocableMethod(Label='Donor Checkin Visit Update' Description='Finds the visit related to this Donor Number and updates it to Checked-in Status with the time.' Category='Donor')
    public static void updateVisitStatus(List<List<Donor_CheckIn__e>> inputRecords) {
        List<List<Donor_CheckIn__e>> validCheckinEvents = (List<List<Donor_CheckIn__e>>)DonorEventHelper.validateDonorAndVisitReferences(inputRecords);
        if (validCheckinEvents.size() == 0) {
            return;
        }

        List<Donor_CheckIn__e> recordsToProcess = new List<Donor_CheckIn__e>();
        Map<String, Donor_CheckIn__e> donorNumberToPEs = new Map<String, Donor_CheckIn__e>();
        List<Datetime> dateTimesToProcess = new List<Datetime>();
        Set<String> donorNumbersToQuery = new Set<String>();
        Map<String, Contact> donorNumberToContact = new Map<String, Contact>();
        Map<String, Visit__c> donorNumberToVisit = new Map<String, Visit__c>();
        List<Visit__c> visitsToUpdate = new List<Visit__c>();

        for (List<Donor_CheckIn__e> recordList : validCheckinEvents) {
            for (Donor_CheckIn__e donorCheckIn : recordList) {
                recordsToProcess.add(donorCheckIn);
                donorNumberToPEs.put(donorCheckIn.Donor_Number__c, donorCheckIn);
                dateTimesToProcess.add(donorCheckIn.Timestamp__c);
                donorNumbersToQuery.add(donorCheckIn.Donor_Number__c);
            }
        }

        // find visits in this list
        for (Visit__c visit : VisitSelector.getVisitsInRangeForDonorNumbers(dateTimesToProcess,donorNumbersToQuery)) {
            Donor_CheckIn__e checkin = donorNumberToPEs.get(visit.Donor__r.Account.DonorId__c);
            // Assuming FDA 48 Hour rule mandates (at least) 24 hours between visits, check if this event is within 12 hours of the Visit (Appointment) Date Time
            if (checkin.Timestamp__c <= visit.Appointment__r.Datetime__c.addHours(12) && checkin.Timestamp__c >= visit.Appointment__r.Datetime__c.addHours(-12)) {
                Visit__c visitUpdate = new Visit__c(Id = visit.Id);
                visitUpdate.Status__c = Constants.VISIT_STATUS_CHECKEDIN;
                visitUpdate.Check_In__c = checkin.Timestamp__c;
                visitsToUpdate.add(visitUpdate);
                donorNumberToVisit.put(checkin.Donor_Number__c, visitUpdate);
            }
        }

        // find Contacts iin this list
        for (Contact ct : [SELECT Id, AccountId, Account.DonorId__c FROM Contact WHERE Account.DonorId__c IN :donorNumbersToQuery]) {
            donorNumberToContact.put(ct.Account.DonorId__c, ct);
        }

        if (!visitsToUpdate.isEmpty()) {
            update visitsToUpdate;
        }
    }
}