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
        Set<String> donorNumbersToQuery = DonorCompInvocableHelper.getDonorIds(inputRecords);
        List<Contact> targetContacts = DonorCompInvocableHelper.queryDonorContactInformation(donorNumbersToQuery);
        Map<Id, Integer> donorIdToTotalVisitCount = DonorBatchableHelper.calculateDonor365DayVisitTotals(targetContacts);

        Map<String, Rate__c> centerAndDonationTypeToRate = DonorCompInvocableHelper.getRatesByCenterDonationType(); // Get All Rates stored by a composite key of Center__c + Donation_Type__c
        Map<Decimal, List<Level__c>> donationThresholdToBonusLevels = DonorCompInvocableHelper.getBonusLevelsByDonationThreshold();
        Map<Id, Map<Id, AggregateResult>> donorIdToActiveLastPromotionDatesByTier = DonorCompInvocableHelper.getDonorLastPromotionDateByLevel(targetContacts);

        Level__c lowestLoyaltyLevel = DonorCompInvocableHelper.getLowestLoyaltyLevel();
        Boolean wasPromotionTriggered = false;

        Map<Id, Transaction__c> donorIdToTransaction = new Map<Id, Transaction__c>();
        Map<Id, List<Txn_Line_Item__c>> donorIdToTxnLineItems = new Map<Id, List<Txn_Line_Item__c>>();
        Map<Id, Transaction_Log__c> donorIdToMissingPaymentMethodLogs = new Map<Id, Transaction_Log__c>();
        Map<Id, List<Message__c>> donorIdToMessages = new Map<Id, List<Message__c>>();

        Map<Id, Account> donorsToUpdate = new Map<Id, Account>();
        List<AddFundsRequest> addFundsRequests = new List<AddFundsRequest>();
        List<DonorPaymentService.DonationPaymentRequest> donationPaymentRequests = new List<DonorPaymentService.DonationPaymentRequest>();
        
        for (Contact foundContact : targetContacts) {
            if (foundContact.Visits__r == null || foundContact.Visits__r.size() == 0) {
                continue;
            }

            Visit__c targetVisitRecord = foundContact.Visits__r[0];
            AddFundsRequest addFundsRequest = DonorCompInvocableHelper.buildBaseAddFundsRequest(foundContact, targetVisitRecord);
            addFundsRequests.add(addFundsRequest);

            Map<Id, AggregateResult> activeLastPromotionDatesByTier = donorIdToActiveLastPromotionDatesByTier.get(foundContact.Id);
            Integer totalVisitCount = donorIdToTotalVisitCount.get(foundContact.Id);

            Rate__c targetRateRecord = centerAndDonationTypeToRate.get(
                targetVisitRecord.Center_Donation_Type__r.Center__c + '-' + targetVisitRecord.Center_Donation_Type__r.Donation_Type__c
            );

            // Create the parent transaction record
            donorIdToTransaction.put(foundContact.Id, DonorCompInvocableHelper.buildBaseTransaction(foundContact, targetVisitRecord));

            // Two Txn Line items need to be created, one for points, one for currency
            List<Txn_Line_Item__c> txnLineItems = new List<Txn_Line_Item__c>();
            txnLineItems.addAll(DonorCompInvocableHelper.buildDonationLineItems(foundContact, targetRateRecord, addFundsRequest));

            // Handle Bonus Level payments (levels that are active but not visible)
            // These levels provide one time payments when the threshold is hit
            List<Level__c> acheivedBonusLevels = donationThresholdToBonusLevels.get(totalVisitCount);
            if (acheivedBonusLevels != null) {
                txnLineItems.addAll(DonorCompInvocableHelper.buildBonusLevelLineItems(foundContact, acheivedBonusLevels, activeLastPromotionDatesByTier, addFundsRequest));
            }

            // Get the target promotional level, this should be the Next_Level__c on the current level
            // If they don't have a current level reference (shouldn't happen), use the lowest level by non-zero threshold
            Level__c targetPromotionLevel;

            if (foundContact.Loyalty_Level__c != null) {
                // Failing this case would indicate that they are at the highest level and can't promote any higher
                if (foundContact.Loyalty_Level__r.Next_Level__c != null) {
                    targetPromotionLevel = foundContact.Loyalty_Level__r.Next_Level__r;
                }
            } else if (lowestLoyaltyLevel != null) {
                targetPromotionLevel = lowestLoyaltyLevel;
            }

            // Check if the amount of donations is equal to the donation threshold
            // If it is and there is another level, promote the donor!
            if (
                foundContact.Loyalty_Level__c != null &&
                targetPromotionLevel != null &&
                totalVisitCount == targetPromotionLevel.Donation_Threshold__c
            ) {
                wasPromotionTriggered = true;

                Account targetDonorToUpdate = donorsToUpdate.get(foundContact.AccountId);
                if (targetDonorToUpdate == null) {
                    targetDonorToUpdate = new Account(Id = foundContact.AccountId);
                }

                targetDonorToUpdate.Loyalty_Level__pc = targetPromotionLevel.Id;
                donorsToUpdate.put(foundContact.AccountId, targetDonorToUpdate);

                // Apply New Level Bonuses onto the line items
                // Check to make sure the bonus level hasn't be triggered in the last 'Loyalty Threshold Window'
                // If it has been triggered, the donor shouldn't receive the bonus
                AggregateResult lastPromotionDate = activeLastPromotionDatesByTier?.get(targetPromotionLevel.Id);
                if (
                    activeLastPromotionDatesByTier == null ||
                    lastPromotionDate == null ||
                    lastPromotionDate.get('lastPromotionDate') == null
                ) {
                    txnLineItems.addAll(DonorCompInvocableHelper.buildPromotionLineItems(targetPromotionLevel, addFundsRequest));
                }
            }

            // Line Items
            List<Txn_Line_Item__c> existingTxnLineItems = (donorIdToTxnLineItems.get(foundContact.Id) != null) ? donorIdToTxnLineItems.get(foundContact.Id) : new List<Txn_Line_Item__c>();
            existingTxnLineItems.addAll(txnLineItems);

            donorIdToTxnLineItems.put(foundContact.Id, txnLineItems);

            // Messages
            List<Message__c> messages = (donorIdToMessages.get(foundContact.Id) != null) ? donorIdToMessages.get(foundContact.Id) : new List<Message__c>();
            messages.add(DonorCompInvocableHelper.buildDonationNotificationMessage(foundContact, targetVisitRecord, wasPromotionTriggered));

            donorIdToMessages.put(foundContact.Id, messages);

            // Check if there needs to be an update to the last used center
            if (foundContact.Account.Last_Used_Center__pc == null || foundContact.Account.Last_Used_Center__pc != targetVisitRecord.Center_Donation_Type__r.Center__c) {
                Account donorToUpdate = donorsToUpdate.get(foundContact.AccountId);
                if (donorToUpdate == null) {
                    donorToUpdate = new Account(Id = foundContact.AccountId);
                }

                donorToUpdate.Last_Used_Center__pc = targetVisitRecord.Center_Donation_Type__r.Center__c;
                donorsToUpdate.put(foundContact.AccountId, donorToUpdate);
            }
        }

        DonorCompInvocableHelper.updateDonorLoyaltyLevels(donorsToUpdate);
        DonorCompInvocableHelper.insertTransactionsAndLineItems(donorIdToTransaction, donorIdToTxnLineItems, donorIdToMessages);
        DonorCompInvocableHelper.insertTransactionLogs(donorIdToMissingPaymentMethodLogs, donorIdToTransaction);

        // Process the add fund requests in an async context to avoid callout exception
        Database.executeBatch(new AddFundsBatchable(addFundsRequests), 100);
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

    public class AddFundsRequest {
        public Id donorContactId;
        public Id visitId;
        public Id debitTransactionId;
        public String existingOnbeTransactionId;

        public List<AddFundsLineItem> lineItems;
        public String accountNumber;
        public String transactionSubType;
        public List<String> comments;
        public Decimal total;

        public Boolean isExceptionPayment;
        public Boolean isSuccessfullyProcessed;
        public String processResponse; // code - sub_code

        public AddFundsRequest(Id donorContactId, Id visitId, String accountNumber, String transactionSubType) {
            this(donorContactId, visitId, accountNumber, transactionSubType, null);
        }

        public AddFundsRequest(Id donorContactId, Id visitId, String accountNumber, String transactionSubType, Id debitTransactionId) {
            this.donorContactId = donorContactId;
            this.visitId = visitId;
            this.accountNumber = accountNumber;
            this.transactionSubType = transactionSubType;
            this.debitTransactionId = debitTransactionId;
            this.existingOnbeTransactionId = '';

            this.comments = new List<String>();
            this.lineItems = new List<AddFundsLineItem>();
            this.total = 0;
            this.isExceptionPayment = false;
        }

        public void setOnbeTransactionId(String transactionId) {
            this.existingOnbeTransactionId = transactionId;
        }

        public void recordAPIResponse(Boolean wasSuccessful, String response) {
            this.isSuccessfullyProcessed = wasSuccessful;
            this.processResponse = response;
        }

        public void addLineItem(String item, String type, Decimal amount) {
            this.lineItems.add(new AddFundsLineItem(item, type, amount));

            if (type == 'Currency') {
                this.total += amount;
            }
        }
    }

    public class AddFundsLineItem {
        public String item;
        public String type;
        public Decimal amount;
        public Integer quantity;

        public AddFundsLineItem(String item, String type, Decimal amount) {
            this(item, type, amount, 1);
        }

        public AddFundsLineItem(String item, String type, Decimal amount, Integer quantity) {
            this.item = item;
            this.type = type;
            this.amount = amount;
            this.quantity = quantity;
        }
    }
}