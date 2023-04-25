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
        Set<String> donorNumbersToQuery = new Set<String>();

        for (List<Donor_Comp__e> recordList : inputRecords) {
            for (Donor_Comp__e donorComp : recordList) {
                donorNumbersToQuery.add(donorComp.Donor_Number__c);
            }
        }

        // Get All Rates stored by a composite key of Center__c + Donation_Type__c
        Map<String, Rate__c> centerAndDonationTypeToRate = new Map<String, Rate__c>();
        for (Rate__c rate : [
            SELECT Id, Center__c, Donation_Type__c, Base_Payment__c
            FROM Rate__c
            WHERE Type__c = 'Base'
        ]) {
            centerAndDonationTypeToRate.put(rate.Center__c + '-' + rate.Donation_Type__c, rate);
        }

        Map<Decimal, List<Level__c>> donationThresholdToBonusLevels = new Map<Decimal, List<Level__c>>();
        for (Level__c bonusLevel : [SELECT Id, Name, Donation_Threshold__c, Threshold_Payment__c, Threshold_Points__c FROM Level__c WHERE isActive__c = true AND isVisible__c = false AND Donation_Threshold__c > 0]) {
            List<Level__c> thresholdBonusLevels = donationThresholdToBonusLevels.get(bonusLevel.Donation_Threshold__c);
            if (thresholdBonusLevels == null) {
                thresholdBonusLevels = new List<Level__c>();
            }

            thresholdBonusLevels.add(bonusLevel);
            donationThresholdToBonusLevels.put(bonusLevel.Donation_Threshold__c, thresholdBonusLevels);
        }

        // Iterate all relevant donors and update loyalty level/create donation transactions
        List<Account> donorsToUpdate = new List<Account>();
        Map<Id, Transaction__c> donorIdToTransaction = new Map<Id, Transaction__c>();
        Map<Id, List<Txn_Line_Item__c>> donorIdToTxnLineItems = new Map<Id, List<Txn_Line_Item__c>>();
        List<Level__c> lowestLoyaltyLevelByThreshold = [
            SELECT Id, Donation_Threshold__c, Threshold_Payment__c, Threshold_Points__c
            FROM Level__c
            WHERE Donation_Threshold__c > 0 AND
            isActive__c = true
            ORDER BY Donation_Threshold__c ASC
            LIMIT 1
        ];

        List<Contact> targetContacts = [
            SELECT Id, AccountId, Loyalty_Level__c, Loyalty_Level__r.Donation_Points__c, Loyalty_Level__r.Donation_Payment__c, Total_Visits_365d__c,
                Loyalty_Level__r.Next_Level__r.Donation_Threshold__c, Loyalty_Level__r.Next_Level__c, Loyalty_Level__r.Next_Level__r.Threshold_Payment__c, Loyalty_Level__r.Next_Level__r.Threshold_Points__c, (
                SELECT Id, Center_Donation_Type__r.Center__c, Center_Donation_Type__r.Donation_Type__c
                FROM Visits__r
                WHERE Status__c = 'Complete' AND Outcome__c = 'Donation'
                ORDER BY Appointment_Datetime__c DESC
            )
            FROM Contact
            WHERE Account.DonorId__c IN :donorNumbersToQuery
        ];

        Map<Id, Integer> donorIdToTotalVisitCount = DonorBatchableHelper.calculateDonor365DayVisitTotals(targetContacts);
        for (Contact foundContact : targetContacts) {
            Integer totalVisitCount = donorIdToTotalVisitCount.get(foundContact.Id);

            if (foundContact.Visits__r == null || foundContact.Visits__r.size() == 0) {
                continue;
            }

            Visit__c targetVisitRecord = foundContact.Visits__r[0];
            Rate__c targetRateRecord = centerAndDonationTypeToRate.get(
                targetVisitRecord.Center_Donation_Type__r.Center__c + '-' + targetVisitRecord.Center_Donation_Type__r.Donation_Type__c
            );

            // Create the parent transaction record
            donorIdToTransaction.put(foundContact.Id, new Transaction__c(
                Donor__c = foundContact.Id,
                Visit__c = targetVisitRecord.Id,
                Type__c = 'Debit'
            ));

            // Two Txn Line items need to be created, one for points, one for currency
            List<Txn_Line_Item__c> txnLineItems = new List<Txn_Line_Item__c>();
            if (foundContact.Loyalty_Level__r.Donation_Points__c != null && foundContact.Loyalty_Level__r.Donation_Points__c > 0) {
                txnLineItems.add(new Txn_Line_Item__c(
                    Item__c = 'Donation Points',
                    Quantity__c = 1,
                    Type__c = 'Points',
                    Unit_Cost__c = foundContact.Loyalty_Level__r.Donation_Points__c
                ));
            }

            Decimal loyaltyLevelPaymentBonus = (foundContact.Loyalty_Level__r.Donation_Payment__c != null) ? foundContact.Loyalty_Level__r.Donation_Payment__c : 0;
            if (targetRateRecord != null && targetRateRecord.Base_Payment__c != null && targetRateRecord.Base_Payment__c > 0) {
                txnLineItems.add(new Txn_Line_Item__c(
                    Item__c = 'Donation Payment',
                    Quantity__c = 1,
                    Type__c = 'Currency',
                    Unit_Cost__c = targetRateRecord.Base_Payment__c + loyaltyLevelPaymentBonus
                ));
            }
            donorIdToTxnLineItems.put(foundContact.Id, txnLineItems);

            // Handle Bonus Level payments (levels that are active but not visible)
            // These levels provide one time payments when the threshold is hit
            for (Decimal bonusLevelThreshold : donationThresholdToBonusLevels.keySet()) {
                if (totalVisitCount == bonusLevelThreshold) {
                    for (Level__c bonusLevel : donationThresholdToBonusLevels.get(bonusLevelThreshold)) {
                        if (bonusLevel.Threshold_Points__c != null && bonusLevel.Threshold_Points__c > 0) {
                            donorIdToTxnLineItems.get(foundContact.Id).add(new Txn_Line_Item__c(
                                Item__c = bonusLevel.Name + ' - Bonus Points',
                                Quantity__c = 1,
                                Type__c = 'Points',
                                Unit_Cost__c = bonusLevel.Threshold_Points__c
                            ));
                        }

                        if (bonusLevel.Threshold_Payment__c != null && bonusLevel.Threshold_Payment__c > 0) {
                            donorIdToTxnLineItems.get(foundContact.Id).add(new Txn_Line_Item__c(
                                Item__c = bonusLevel.Name + ' - Bonus Payment',
                                Quantity__c = 1,
                                Type__c = 'Currency',
                                Unit_Cost__c = bonusLevel.Threshold_Payment__c
                            ));
                        }
                    }

                    break;
                }
            }

            // Get the target promotional level, this should be the Next_Level__c on the current level
            // If they don't have a current level reference (shouldn\'t happen), use the lowest level by non-zero threshold
            Level__c targetPromotionLevel;

            if (foundContact.Loyalty_Level__c != null && foundContact.Loyalty_Level__r.Next_Level__c != null) {
                targetPromotionLevel = foundContact.Loyalty_Level__r.Next_Level__r;
            } else if (lowestLoyaltyLevelByThreshold != null && lowestLoyaltyLevelByThreshold.size() > 0) {
                targetPromotionLevel = lowestLoyaltyLevelByThreshold[0];
            }

            // Check if the amount of donations is greater than or equal to the donation threshold
            // If it is and there is another level, promote the donor!
            if (
                foundContact.Loyalty_Level__c != null &&
                    targetPromotionLevel != null &&
                    totalVisitCount == targetPromotionLevel.Donation_Threshold__c
            ) {
                donorsToUpdate.add(new Account(Id = foundContact.AccountId, Loyalty_Level__pc = targetPromotionLevel.Id));

                // Apply New Level Bonuses onto the line items
                List<Txn_Line_Item__c> lineItems = donorIdToTxnLineItems.get(foundContact.Id);

                if (targetPromotionLevel.Threshold_Points__c != null && targetPromotionLevel.Threshold_Points__c > 0) {
                    lineItems.add(new Txn_Line_Item__c(
                        Item__c = 'Threshold Points',
                        Quantity__c = 1,
                        Type__c = 'Points',
                        Unit_Cost__c = targetPromotionLevel.Threshold_Points__c
                    ));
                }

                if (targetPromotionLevel.Threshold_Payment__c != null && targetPromotionLevel.Threshold_Payment__c > 0) {
                    lineItems.add(new Txn_Line_Item__c(
                        Item__c = 'Threshold Payment',
                        Quantity__c = 1,
                        Type__c = 'Currency',
                        Unit_Cost__c = targetPromotionLevel.Threshold_Payment__c
                    ));
                }
            }
        }
        update donorsToUpdate;

        // Inserting the transactions and line items
        insert donorIdToTransaction.values();

        List<Txn_Line_Item__c> txnLineItems = new List<Txn_Line_Item__c>();
        for (Transaction__c transactionRecord : donorIdToTransaction.values()) {
            // Relate the transaction to the line items
            for (Txn_Line_Item__c lineItem : donorIdToTxnLineItems.get(transactionRecord.Donor__c)) {
                lineItem.Transaction__c = transactionRecord.Id;
            }

            txnLineItems.addAll(donorIdToTxnLineItems.get(transactionRecord.Donor__c));
        }

        insert txnLineItems;
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

        for (CampaignMember cm : [
            SELECT Id,
                ContactId,
                CampaignId,
                Eligible_Donation_Count__c,
                CreatedDate
            FROM CampaignMember
            WHERE Campaign.IsActive = TRUE
            AND Campaign.Type = 'Incentive'
            AND ContactId IN :donorToCampaignMembers.keySet()
        ]) {
            List<CampaignMember> donorCMs = donorToCampaignMembers.get(cm.ContactId);
            cm.Eligible_Donation_Count__c = 0; // set to zero; we want to recount these in case something changes
            donorCMs.add(cm);
            donorToCampaignMembers.put(cm.ContactId, donorCMs);
            datesInRange.add(Date.valueOf(cm.CreatedDate));
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
                    Date checkDate = Date.valueOf(cm.CreatedDate);
                    if (donorToVisitsInRange.get(cm.ContactId).size() >= 1) {
                        for (Visit__c visit : donorToVisitsInRange.get(cm.ContactId)) {
                            if (Date.valueOf(visit.Appointment_Datetime__c) >= checkDate) {
                                campaignMemberVisitCounter++;
                            }
                        }
                    }
                    CampaignMember cmUpdate = new CampaignMember(
                        Id = cm.Id,
                        Eligible_Donation_Count__c = campaignMemberVisitCounter
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