/**
 * Created by joshlequire1 on 3/10/23.
 */

public without sharing class DonorCompInvocable {
    @InvocableMethod(Label='Handle Donor Comp Event' Description='Handles the Donor Comp Event by updating the Visit Status to Complete and creating a Donation Transaction' Category='Donor')
    public static void handleDonorCompEvent(List<List<Donor_Comp__e>> inputRecords) {
        updateVisitStatusComplete(inputRecords);
        handleCreateDonationTransactions(inputRecords);
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
        ]) {
            centerAndDonationTypeToRate.put(rate.Center__c + '-' + rate.Donation_Type__c, rate);
        }

        // Iterate all relevant donors and update loyalty level/create donation transactions
        List<Account> donorsToUpdate = new List<Account>();
        Map<Id, Transaction__c> donorIdToTransaction = new Map<Id, Transaction__c>();
        Map<Id, List<Txn_Line_Item__c>> donorIdToTxnLineItems = new Map<Id, List<Txn_Line_Item__c>>();

        for(Contact foundContact : [
            SELECT Id, AccountId, Loyalty_Level__c, Loyalty_Level__r.Donation_Points__c, Loyalty_Level__r.Donation_Payment__c,
            Loyalty_Level__r.Next_Level__r.Donation_Threshold__c, Loyalty_Level__r.Next_Level__c, Loyalty_Level__r.Next_Level__r.Threshold_Payment__c, Loyalty_Level__r.Next_Level__r.Threshold_Points__c, (
                SELECT Id, Center_Donation_Type__r.Center__c, Center_Donation_Type__r.Donation_Type__c 
                FROM Visits__r 
                WHERE Status__c = 'Complete' AND Outcome__c = 'Donation' 
                ORDER BY Appointment_Datetime__c DESC
            ) 
            FROM Contact 
            WHERE Account.DonorId__c IN :donorNumbersToQuery
        ]) {
            if (foundContact.Visits__r == null || foundContact.Visits__r.size() == 0 || foundContact.Loyalty_Level__c == null) {
                continue;
            }

            // Create the parent transaction record
            donorIdToTransaction.put(foundContact.Id, new Transaction__c(
                Donor__c = foundContact.Id,
                Visit__c = foundContact.Visits__r[0].Id,
                Type__c = 'Credit'
            ));

            // Two Txn Line items need to be created, one for points, one for currency
            Visit__c targetVisitRecord = foundContact.Visits__r[0];
            Rate__c targetRateRecord = centerAndDonationTypeToRate.get(
                targetVisitRecord.Center_Donation_Type__r.Center__c + '-' + targetVisitRecord.Center_Donation_Type__r.Donation_Type__c
            );

            List<Txn_Line_Item__c> txnLineItems = new List<Txn_Line_Item__c>();
            if (foundContact.Loyalty_Level__r.Donation_Points__c != null && foundContact.Loyalty_Level__r.Donation_Points__c > 0) {
                txnLineItems.add(new Txn_Line_Item__c(
                    Item__c	= 'Donation Points',
                    Quantity__c = 1,
                    Type__c = 'Points',
                    Unit_Cost__c = foundContact.Loyalty_Level__r.Donation_Points__c
                ));
            }

            Decimal loyaltyLevelPaymentBonus = (foundContact.Loyalty_Level__r.Donation_Payment__c != null) ? foundContact.Loyalty_Level__r.Donation_Payment__c : 0;
            if (targetRateRecord != null && targetRateRecord.Base_Payment__c != null && targetRateRecord.Base_Payment__c > 0) {
                txnLineItems.add(new Txn_Line_Item__c(
                    Item__c	= 'Donation Payment',
                    Quantity__c = 1,
                    Type__c = 'Currency',
                    Unit_Cost__c = targetRateRecord.Base_Payment__c + loyaltyLevelPaymentBonus
                ));
            }
            donorIdToTxnLineItems.put(foundContact.Id, txnLineItems);

            // Check if the amount of donations is greater than or equal to the donation threshold
            // If it is and there is another level, promote the donor!
            if (
                foundContact.Loyalty_Level__r.Next_Level__c != null && 
                foundContact.Visits__r.size() == foundContact.Loyalty_Level__r.Next_Level__r.Donation_Threshold__c
            ) {
                // foundContact.Loyalty_Level__c = foundContact.Loyalty_Level__r.Next_Level__c;
                donorsToUpdate.add(new Account(Id = foundContact.AccountId, Loyalty_Level__pc = foundContact.Loyalty_Level__r.Next_Level__c));

                // Apply New Level Bonuses onto the line items
                List<Txn_Line_Item__c> lineItems = donorIdToTxnLineItems.get(foundContact.Id);

                if (foundContact.Loyalty_Level__r.Next_Level__r != null && foundContact.Loyalty_Level__r.Next_Level__r.Threshold_Points__c != null && foundContact.Loyalty_Level__r.Next_Level__r.Threshold_Points__c > 0) {
                    lineItems.add(new Txn_Line_Item__c(
                        Item__c	= 'Threshold Points',
                        Quantity__c = 1,
                        Type__c = 'Points',
                        Unit_Cost__c = foundContact.Loyalty_Level__r.Next_Level__r.Threshold_Points__c
                    ));
                }

                if (foundContact.Loyalty_Level__r.Next_Level__r != null && foundContact.Loyalty_Level__r.Next_Level__r.Threshold_Payment__c != null && foundContact.Loyalty_Level__r.Next_Level__r.Threshold_Payment__c > 0) {
                    lineItems.add(new Txn_Line_Item__c(
                        Item__c	= 'Threshold Payment',
                        Quantity__c = 1,
                        Type__c = 'Currency',
                        Unit_Cost__c = foundContact.Loyalty_Level__r.Next_Level__r.Threshold_Payment__c
                    ));
                }
            }
        }
        update donorsToUpdate;

        // Inserting the transactions and line items
        insert donorIdToTransaction.values();

        List<Txn_Line_Item__c> txnLineItems = new List<Txn_Line_Item__c>();
        for(Transaction__c transactionRecord : donorIdToTransaction.values()) {
            // Relate the transaction to the line items
            for (Txn_Line_Item__c lineItem : donorIdToTxnLineItems.get(transactionRecord.Donor__c)) {
                lineItem.Transaction__c = transactionRecord.Id;
            }

            txnLineItems.addAll(donorIdToTxnLineItems.get(transactionRecord.Donor__c));
        }

        insert txnLineItems;
    }
}