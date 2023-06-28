/**
 * Created by joshlequire1 on 3/10/23.
 */

public without sharing class DonorCompInvocable {
    @InvocableMethod(Label='Handle Donor Comp Event' Description='Handles the Donor Comp Event by updating the Visit Status to Complete and creating a Donation Transaction' Category='Donor')
    public static void handleDonorCompEvent(List<List<Donor_Comp__e>> inputRecords) {
        // Donor Comp Events returned by this function have both a valid donor and visit reference
        List<List<Donor_Comp__e>> validDonorEvents = (List<List<Donor_Comp__e>>) DonorEventHelper.validateDonorAndVisitReferences(inputRecords);

        if (!validDonorEvents.isEmpty()) {
            updateVisitStatusComplete(validDonorEvents);
            handleCreateDonationTransactions(validDonorEvents);
        }
    }

    // NOTE (similar to Donor Checkin), this assumes we'll receive a call for each unique comp event at the Donor_Comp__e endpoint, but is bulkfied in case there is a need for processing these in larger batches. However, this method assumes only 1 check in per Donor Number - if multiple checkinis for the same donor are needed with this call, we'll need to refactor the method to handle this.
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
        for (Visit__c visit : VisitSelector.getVisitsInRangeForDonorNumbers(dateTimesToProcess, donorNumbersToQuery)) {
            Donor_Comp__e comp = donorNumberToPEs.get(visit.Donor__r.Account.DonorId__c);
            // Assuming FDA 48 Hour rule mandates (at least) 24 hours between visits, check if this event is within 12 hours of the Visit (Appointment) Date Time
            if (comp.Timestamp__c <= visit.Appointment__r.Datetime__c.addHours(12) && comp.Timestamp__c >= visit.Appointment__r.Datetime__c.addHours(-12)) {
                Visit__c visitUpdate = new Visit__c(Id = visit.Id,
                    Donor__c = visit.Donor__c);
                updateVisitToCompleteDonationStatus(visitUpdate, comp);

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
            updateCampaignVisitCounter(visitsToUpdate);
        }
    }

    private static Visit__c updateVisitToCompleteDonationStatus(Visit__c visit, Donor_Comp__e comp) {
        visit.Status__c = Constants.VISIT_STATUS_COMPLETE;
        visit.Donation_Complete__c = comp.Timestamp__c;
        visit.Outcome__c = Constants.VISIT_OUTCOME_DONATION;
        visit.Collection_Number__c = comp.Collection_Number__c;
        visit.Donation_Volume__c = comp.Collection_Volume__c;
        visit.Collection_Device_ID__c = comp.BECS_Device__c;

        return visit;
    }

    public static void handleCreateDonationTransactions(List<List<Donor_Comp__e>> inputRecords) {
        Set<String> donorNumbers = new Set<String>();
        for (List<Donor_Comp__e> recordList : inputRecords) {
            for (Donor_Comp__e donorComp : recordList) {
                donorNumbers.add(donorComp.Donor_Number__c);
            }
        }

        List<DonorPaymentService.DonationPaymentRequest> paymentRequests = new List<DonorPaymentService.DonationPaymentRequest>();
        for(Contact foundContact : [
            SELECT Id, (SELECT Id FROM Visits__r WHERE Status__c = 'Complete' AND Outcome__c = 'Donation' ORDER BY Appointment_Datetime__c DESC LIMIT 1) 
            FROM Contact 
            WHERE Account.DonorId__c IN :donorNumbers
        ]) {
            if (foundContact.Visits__r.isEmpty()) {
                continue;
            }

            paymentRequests.add(new DonorPaymentService.DonationPaymentRequest(foundContact.Id, foundContact.Visits__r[0].Id));
        }

        DonorPaymentService.createDonationPayment(paymentRequests);
    }

    public static void updateCampaignVisitCounter(List<Visit__c> visitsToProcess) {
        Map<Id, List<CampaignMember>> donorToCampaignMembers = new Map<Id, List<CampaignMember>>();
        List<Date> datesInRange = new List<Date>();
        Map<Id, List<Visit__c>> donorToVisitsInRange = new Map<Id, List<Visit__c>>();
        List<CampaignMember> finalCampaignMemberUpdates = new List<CampaignMember>();

        for (Visit__c visit : visitsToProcess) {
            donorToCampaignMembers.put(visit.Donor__c, new List<CampaignMember>());
            donorToVisitsInRange.put(visit.Donor__c, new List<Visit__c>());
        }

        // The Campaign Member Trigger assumes the visit counter assumes this query (below) is looking only at active Incentive Type Campaigns. If this changes, verify the login in the Campaign Member Trigger Handler class is correct.
        for (CampaignMember cm : [
            SELECT Id,
                ContactId,
                CampaignId,
                Eligible_Donation_Count__c,
                CreatedDate
            FROM CampaignMember
            WHERE Campaign.IsActive = TRUE
            AND Campaign.Type = :Constants.CAMPAIGN_TYPE_INCENTIVE
            AND ContactId IN :donorToCampaignMembers.keySet()
        ]) {
            List<CampaignMember> donorCMs = donorToCampaignMembers.get(cm.ContactId);
            cm.Eligible_Donation_Count__c = 0; // set to zero; we want to recount these in case something changes
            donorCMs.add(cm);
            donorToCampaignMembers.put(cm.ContactId, donorCMs);
            datesInRange.add(cm.CreatedDate.date());
        }

        if (datesInRange.size() == 0) {
            return;
        }

        datesInRange.sort();
        Date minDate = datesInRange[0];
        Time minTime = Time.newInstance(0, 0, 0, 0);
        Datetime minDateTime = Datetime.newInstance(minDate, minTime);

        for (Visit__c visit : [
            SELECT Id,
                Appointment_Datetime__c,
                Donor__c
            FROM Visit__c
            WHERE Donor__c IN :donorToVisitsInRange.keySet()
            AND Status__c = :Constants.VISIT_STATUS_COMPLETE
            AND Outcome__c = :Constants.VISIT_OUTCOME_DONATION
            AND Appointment_Datetime__c >= :minDateTime
        ]) {
            List<Visit__c> donorVisits = donorToVisitsInRange.get(visit.Donor__c);
            donorVisits.add(visit);
            donorToVisitsInRange.put(visit.Donor__c, donorVisits);
        }

        for (Id donorId : donorToCampaignMembers.keySet()) {
            if (donorToCampaignMembers.get(donorId).size() >= 1) {
                for (CampaignMember cm : donorToCampaignMembers.get(donorId)) {
                    Integer campaignMemberVisitCounter = 0;
                    String latestVisitId = null;
                    Datetime maxDateTime = Datetime.newInstance(1900, 01, 01, 00, 00, 00);
                    Date checkDate = cm.CreatedDate.date();
                    if (donorToVisitsInRange.get(cm.ContactId).size() >= 1) {
                        for (Visit__c visit : donorToVisitsInRange.get(cm.ContactId)) {
                            if (Date.valueOf(visit.Appointment_Datetime__c) >= checkDate) {
                                campaignMemberVisitCounter++;
                                if (visit.Appointment_Datetime__c > maxDateTime) {
                                    maxDateTime = visit.Appointment_Datetime__c;
                                    latestVisitId = visit.Id;
                                }
                            }
                        }
                    }
                    CampaignMember cmUpdate = new CampaignMember(
                        Id = cm.Id,
                        Eligible_Donation_Count__c = campaignMemberVisitCounter,
                        Last_Related_Visit__c = latestVisitId
                    );
                    finalCampaignMemberUpdates.add(cmUpdate);
                }
            }
        }
        if (!finalCampaignMemberUpdates.isEmpty()) {
            update finalCampaignMemberUpdates;
        }
    }
}