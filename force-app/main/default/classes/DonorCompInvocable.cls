/**
 * Created by joshlequire1 on 3/10/23.
 */

public without sharing class DonorCompInvocable {
    // NOTE (similar to Donor Checkin), this assumes we'll receive a call for each unique comp event at the Donor_Comp__e endpoint, but is bulkfied in case there is a need for processing these in larger batches. However, this method assumes only 1 check in per Donor Number - if multiple checkinis for the same donor are needed with this call, we'll need to refactor the method to handle this.
    @InvocableMethod(Label='Donor Comp Visit Update' Description='Finds the visit related to this Donor Number and updates it to Complete with the time.' Category='Donor')
    public static void updateVisitStatusComplete(List<List<Donor_Comp__e>> inputRecords) {
        List<Donor_Comp__e> recordsToProcess = new List<Donor_Comp__e>();
        Map<String, Donor_Comp__e> donorNumberToPEs = new Map<String, Donor_Comp__e>();
        List<Datetime> dateTimesToProcess = new List<Datetime>();
        Set<String> donorNumbersToQuery = new Set<String>();
        Map<String, Contact> donorNumberToContact = new Map<String, Contact>();
        Map<String, Visit__c> donorNumberToVisit = new Map<String, Visit__c>();
        List<Visit__c> visitsToUpdate = new List<Visit__c>();

        for (List<Donor_Comp__e> recordList : inputRecords) {
            for (Donor_Comp__e donorComp : recordList) {
                recordsToProcess.add(donorComp);
                donorNumberToPEs.put(donorComp.Donor_Number__c, donorComp);
                dateTimesToProcess.add(donorComp.Timestamp__c);
                donorNumbersToQuery.add(donorComp.Donor_Number__c);
            }
        }

        // find visits in this list
        for (Visit__c visit : VisitSelector.getVisitsInRangeForDonorNumbers(dateTimesToProcess,donorNumbersToQuery)) {
            Donor_Comp__e comp = donorNumberToPEs.get(visit.Donor__r.Account.DonorId__c);
            // Assuming FDA 48 Hour rule mandates (at least) 24 hours between visits, check if this event is within 12 hours of the Visit (Appointment) Date Time
            if (comp.Timestamp__c <= visit.Appointment__r.Datetime__c.addHours(12) && comp.Timestamp__c >= visit.Appointment__r.Datetime__c.addHours(-12)) {
                Visit__c visitUpdate = new Visit__c(Id = visit.Id);
                visitUpdate.Status__c = Constants.VISIT_STATUS_COMPLETE;
                visitUpdate.Donation_Complete__c = comp.Timestamp__c;
                visitUpdate.Outcome__c = Constants.VISIT_OUTCOME_DONATION;
                visitUpdate.Collection_Number__c = comp.Collection_Number__c;
                visitUpdate.Donation_Volume__c = comp.Collection_Volume__c;
                visitUpdate.Collection_Device_ID__c = comp.BECS_Device__c;
                visitsToUpdate.add(visitUpdate);
                donorNumberToVisit.put(comp.Donor_Number__c, visitUpdate);
            }
        }

        // find Contacts iin this list
        for (Contact ct : [SELECT Id, AccountId, Account.DonorId__c FROM Contact WHERE Account.DonorId__c IN :donorNumbersToQuery]) {
            donorNumberToContact.put(ct.Account.DonorId__c, ct);
        }

        if (!visitsToUpdate.isEmpty()) {
            update visitsToUpdate;
        }

        // Find Donor Numbers that weren't matched to Visits and Contacts for Processing Exceptions (currently to ErrorLog__c records)
        List<ErrorLog__c> errorEvents = new List<ErrorLog__c>();
        for (String donorNumber : donorNumbersToQuery) {
            if (donorNumberToVisit.get(donorNumber) == null) {
                ErrorLog__c errorEvent = new ErrorLog__c();
                errorEvent.Origin__c = 'DonorCompInvocable.updateVisitStatusComplete';
                errorEvent.ShortMessage__c = 'Donor Comp Event Exception';
                if (donorNumberToContact.get(donorNumber) == null) {
                    errorEvent.ShortMessage__c = errorEvent.ShortMessage__c + ': No matching donor';
                } else {
                    errorEvent.ShortMessage__c = errorEvent.ShortMessage__c + ': No matching visit';
                }
                errorEvent.Type__c = Constants.ERRORLOG_TYPE_WARNING;
                errorEvent.LongMessage__c = 'Platform Event Record Detail: ' + '/n' + String.valueOf(donorNumberToPEs.get(donorNumber));
                errorEvents.add(errorEvent);
            }
        }

        if (!errorEvents.isEmpty()) {
            insert errorEvents;
        }

    }
}