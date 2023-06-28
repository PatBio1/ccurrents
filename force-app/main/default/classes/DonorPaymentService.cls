public without sharing class DonorPaymentService {
    public static List<DonationPaymentResponse> createDonationPayment(List<DonationPaymentRequest> paymentRequests) {
        Set<Id> donorContactIds = new Set<Id>();
        Set<Id> visitIds = new Set<Id>();

        for(DonationPaymentRequest paymentRequest : paymentRequests) {
            donorContactIds.add(paymentRequest.donorId);
            visitIds.add(paymentRequest.visitId);
        }

        List<Contact> targetContacts = DonorPaymentServiceHelper.queryDonorContactInformation(donorContactIds, visitIds);
        Map<Id, Integer> donorIdToTotalVisitCount = DonorBatchableHelper.calculateDonor365DayVisitTotals(targetContacts);

        Map<String, Rate__c> centerAndDonationTypeToRate = DonorPaymentServiceHelper.getRatesByCenterDonationType(); // Get All Rates stored by a composite key of Center__c + Donation_Type__c
        Map<Decimal, List<Level__c>> donationThresholdToBonusLevels = DonorPaymentServiceHelper.getBonusLevelsByDonationThreshold();
        Map<Id, Map<Id, AggregateResult>> donorIdToActiveLastPromotionDatesByTier = DonorPaymentServiceHelper.getDonorLastPromotionDateByLevel(targetContacts);

        Level__c lowestLoyaltyLevel = DonorPaymentServiceHelper.getLowestLoyaltyLevel();
        Boolean wasPromotionTriggered = false;

        List<DonationPaymentResponse> donationPaymentResponses = new List<DonationPaymentResponse>();
        Map<Id, Account> donorsToUpdate = new Map<Id, Account>();
        List<ProesisAddFundsRequest> addFundsRequests = new List<ProesisAddFundsRequest>();
        List<DonorPaymentService.DonationPaymentRequest> donationPaymentRequests = new List<DonorPaymentService.DonationPaymentRequest>();
        
        for (Contact foundContact : targetContacts) {
            for(Visit__c targetVisitRecord : foundContact.Visits__r) {
                ProesisAddFundsRequest addFundsRequest = DonorPaymentServiceHelper.buildBaseAddFundsRequest(foundContact, targetVisitRecord);
                addFundsRequests.add(addFundsRequest);

                DonationPaymentResponse donationPaymentResponse = new DonationPaymentResponse(foundContact.Id, targetVisitRecord.Id);
                donationPaymentResponses.add(donationPaymentResponse);

                Map<Id, AggregateResult> activeLastPromotionDatesByTier = donorIdToActiveLastPromotionDatesByTier.get(foundContact.Id);
                Integer totalVisitCount = donorIdToTotalVisitCount.get(foundContact.Id);

                Rate__c targetRateRecord = centerAndDonationTypeToRate.get(
                    targetVisitRecord.Center_Donation_Type__r.Center__c + '-' + targetVisitRecord.Center_Donation_Type__r.Donation_Type__c
                );

                // Create the parent transaction record
                donationPaymentResponse.transactionRecord = DonorPaymentServiceHelper.buildBaseTransaction(foundContact, targetVisitRecord);

                // Two Txn Line items need to be created, one for points, one for currency
                List<Txn_Line_Item__c> txnLineItems = new List<Txn_Line_Item__c>();
                txnLineItems.addAll(DonorPaymentServiceHelper.buildDonationLineItems(foundContact, targetRateRecord, addFundsRequest));

                // Handle Bonus Level payments (levels that are active but not visible)
                // These levels provide one time payments when the threshold is hit
                List<Level__c> acheivedBonusLevels = donationThresholdToBonusLevels.get(totalVisitCount);
                if (acheivedBonusLevels != null) {
                    txnLineItems.addAll(DonorPaymentServiceHelper.buildBonusLevelLineItems(foundContact, acheivedBonusLevels, activeLastPromotionDatesByTier, addFundsRequest));
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
                        txnLineItems.addAll(DonorPaymentServiceHelper.buildPromotionLineItems(targetPromotionLevel, addFundsRequest));
                    }
                }

                donationPaymentResponse.txnLineItems.addAll(txnLineItems);
                donationPaymentResponse.donationMessages.add(DonorPaymentServiceHelper.buildDonationNotificationMessage(foundContact, targetVisitRecord, wasPromotionTriggered));

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
        }

        DonorPaymentServiceHelper.updateDonorLoyaltyLevels(donorsToUpdate);
        DonorPaymentServiceHelper.insertTransactionsAndLineItems(donationPaymentResponses);

        // Process the add fund requests in an async context to avoid callout exception
        Database.executeBatch(new AddFundsBatchable(addFundsRequests), 100);
        return donationPaymentResponses;
    }

    public class DonationPaymentRequest {
        public Id donorId;
        public Id visitId;

        public DonationPaymentRequest(Id donorId, Id visitId) {
            this.donorId = donorId;
            this.visitId = visitId;
        }
    }

    public class DonationPaymentResponse {
        public Id donorId;
        public Id visitId;

        public Transaction__c transactionRecord;
        public List<Txn_Line_Item__c> txnLineItems;
        public List<Message__c> donationMessages;

        public DonationPaymentResponse(Id donorId, Id visitId) {
            this.donorId = donorId;
            this.visitId = visitId;

            this.txnLineItems = new List<Txn_Line_Item__c>();
            this.donationMessages = new List<Message__c>();
        }
    }

    public static List<ExceptionPaymentResponse> createExceptionPayment(List<ExceptionPaymentRequest> exceptionRequests) {
        List<ProesisAddFundsRequest> addFundsRequests = new List<ProesisAddFundsRequest>();
        
        Set<Id> exceptionRateIds = new Set<Id>();
        Set<Id> visitIds = new Set<Id>();

        for (ExceptionPaymentRequest exceptionRequest : exceptionRequests) {
            if (exceptionRequest.exceptionRateId != null && (exceptionRequest.exceptionAmount == null || String.isEmpty(exceptionRequest.exceptionReason))) {
                exceptionRateIds.add(exceptionRequest.exceptionRateId);
            }
            
            visitIds.add(exceptionRequest.visitId);
        }

        Map<Id, String> donorIdToPaymentMethodAccountNumber = new Map<Id, String>();
        for(Payment_Method__c paymentMethod : [
            SELECT Id, Account_Number__c, Donor__c
            FROM Payment_Method__c
            WHERE Donor__c IN (SELECT Donor__c FROM Visit__c WHERE Id IN :visitIds) AND
                Is_Active__c = true AND 
                isDefault__c = true
        ]) {
            donorIdToPaymentMethodAccountNumber.put(paymentMethod.Donor__c, paymentMethod.Account_Number__c);
        }

        // Verify Exception Limits haven't been exceeded before creating transactions
        Map<Id, Rate__c> exceptionRates;
        if (exceptionRateIds.size() > 0) {
            exceptionRates = new Map<Id, Rate__c>([
                SELECT Id, Base_Payment__c, Description__c, Center__c
                FROM Rate__c
                WHERE Id IN :exceptionRateIds
            ]);
        }

        Map<Id, Account> centerIdToCenter = new Map<Id, Account>();
        for(Visit__c targetVisit : [
            SELECT Id, Center_Donation_Type__r.Center__r.Name, Center_Donation_Type__r.Center__r.Max_Dollar_Per_Day__c, Center_Donation_Type__r.Center__r.Individual_Exception_Limit__c 
            FROM Visit__c 
            WHERE Id IN :visitIds
        ]) {
            centerIdToCenter.put(targetVisit.Id, targetVisit.Center_Donation_Type__r.Center__r);
        }

        Map<Id, Decimal> centerIdToTotalExceptionAmount = new Map<Id, Decimal>();
        for (AggregateResult result : [
            SELECT Visit__r.Center_Donation_Type__r.Center__c centerId, SUM(Amount_Currency__c) totalExceptionAmount
            FROM Transaction__c
            WHERE Visit__c IN :visitIds AND
                Type__c = 'Credit' AND
                SubType__c = 'Exception' AND 
                CreatedDate = TODAY
            GROUP BY Visit__r.Center_Donation_Type__r.Center__c
        ]) {
            centerIdToTotalExceptionAmount.put((Id)result.get('centerId'), (Decimal)result.get('totalExceptionAmount'));
        }

        for (ExceptionPaymentRequest exceptionRequest : exceptionRequests) {
            Decimal exceptionAmount;
            String exceptionReason;
            
            if (!String.isEmpty(exceptionRequest.exceptionRateId)) {
                Rate__c exceptionRate = exceptionRates.get(exceptionRequest.exceptionRateId);
                exceptionAmount = exceptionRate.Base_Payment__c;
                exceptionReason = exceptionRate.Description__c;
            } else {
                exceptionAmount = exceptionRequest.exceptionAmount;
                exceptionReason = exceptionRequest.exceptionReason;
            }

            Account center = centerIdToCenter.get(exceptionRequest.visitId);

            Decimal totalExceptionAmount = centerIdToTotalExceptionAmount.get(center.Id);
            if (totalExceptionAmount == null) {
                totalExceptionAmount = 0;
            }

            totalExceptionAmount += exceptionAmount;
            centerIdToTotalExceptionAmount.put(center.Id, totalExceptionAmount);

            if ((center.Max_Dollar_Per_Day__c != null && center.Max_Dollar_Per_Day__c > 0) && totalExceptionAmount > center.Max_Dollar_Per_Day__c) {
                throw new DonorPaymentException(String.format(Constants.CENTER_DAY_EXCEPTION_LIMIT_ERROR, new List<object> { center.Name }));
            }

            if ((center.Individual_Exception_Limit__c != null && center.Individual_Exception_Limit__c > 0) && exceptionAmount > center.Individual_Exception_Limit__c) {
                throw new DonorPaymentException(String.format(Constants.CENTER_INDIVIDUAL_EXCEPTION_LIMIT_ERROR, new List<object> { center.Name }));
            }

            ProesisAddFundsRequest addFundsRequest = new ProesisAddFundsRequest(
                exceptionRequest.donorId, exceptionRequest.visitId, donorIdToPaymentMethodAccountNumber.get(exceptionRequest.donorId), 'Exception'
            );

            addFundsRequest.addLineItem(exceptionReason, 'Currency', exceptionAmount);
            addFundsRequest.comments.add('Exception Payment - ' + exceptionReason);
            addFundsRequest.isExceptionPayment = true;

            addFundsRequests.add(addFundsRequest);
        }
        
        // Assuming no exceptions, create the actual transactions
        Map<Id, Transaction__c> visitIdToTransaction = new Map<Id, Transaction__c>();
        Map<Id, Task> visitIdToExceptionPaymentTask = new Map<Id, Task>();

        List<Group> targetExceptionPaymentTaskQueue = [SELECT Id FROM Group WHERE DeveloperName = 'Proesis_Operations' LIMIT 1];
        for(ExceptionPaymentRequest exceptionRequest : exceptionRequests) {
            String exceptionReason;
            
            if (!String.isEmpty(exceptionRequest.exceptionRateId)) {
                Rate__c exceptionRate = exceptionRates.get(exceptionRequest.exceptionRateId);
                exceptionReason = exceptionRate.Description__c;
            } else {
                exceptionReason = exceptionRequest.exceptionReason;
            }
            
            Transaction__c exceptionTransaction = new Transaction__c(
                Donor__c = exceptionRequest.donorId,
                Visit__c = exceptionRequest.visitId,
                Status__c = 'Complete',
                Type__c = 'Credit',
                SubType__c = 'Exception'
            );

            Task exceptionPaymentTask = new Task(
                WhoId = exceptionRequest.donorId,
                WhatId = exceptionRequest.visitId,
                Subject = 'Exception Payment - ' + exceptionReason,
                ActivityDate = Date.today(),
                OwnerId = targetExceptionPaymentTaskQueue[0].Id
            );

            visitIdToExceptionPaymentTask.put(exceptionRequest.visitId, exceptionPaymentTask);
            visitIdToTransaction.put(exceptionRequest.visitId, exceptionTransaction);
        }

        insert visitIdToTransaction.values();
        insert visitIdToExceptionPaymentTask.values();

        List<Txn_Line_Item__c> lineItems = new List<Txn_Line_Item__c>();
        List<ExceptionPaymentResponse> exceptionResponses = new List<ExceptionPaymentResponse>();

        for (ExceptionPaymentRequest exceptionRequest : exceptionRequests) {
            Transaction__c exceptionTransaction = visitIdToTransaction.get(exceptionRequest.visitId);
            Decimal exceptionAmount;
            String exceptionReason;
            
            if (!String.isEmpty(exceptionRequest.exceptionRateId)) {
                Rate__c exceptionRate = exceptionRates.get(exceptionRequest.exceptionRateId);
                exceptionAmount = exceptionRate.Base_Payment__c;
                exceptionReason = exceptionRate.Description__c;
            } else {
                exceptionAmount = exceptionRequest.exceptionAmount;
                exceptionReason = exceptionRequest.exceptionReason;
            }
            
            exceptionResponses.add(new ExceptionPaymentResponse(exceptionRequest.donorId, exceptionRequest.visitId, exceptionAmount, exceptionReason, exceptionTransaction.Id));
            lineItems.add(new Txn_Line_Item__c(
                Transaction__c = exceptionTransaction.Id,
                Item__c = exceptionReason,
                Unit_Cost__c = exceptionAmount,
                Quantity__c = 1,
                Type__c = 'Currency'
            ));
        }
        insert lineItems;

        Database.executeBatch(new AddFundsBatchable(addFundsRequests), 100);
        return exceptionResponses;
    }

    public class ExceptionPaymentRequest {
        public Id donorId;
        public Id visitId;
        public Id exceptionRateId;

        public Decimal exceptionAmount;
        public String exceptionReason;

        public ExceptionPaymentRequest(Id donorId, Id visitId, Id exceptionRateId) {
            this.donorId = donorId;
            this.visitId = visitId;
            this.exceptionRateId = exceptionRateId;
        }

        public ExceptionPaymentRequest(Id donorId, Id visitId, Decimal amount, String reason) {
            this.donorId = donorId;
            this.visitId = visitId;
            this.exceptionAmount = amount;
            this.exceptionReason = reason;
        }
    }

    public class ExceptionPaymentResponse {
        public Id donorId;
        public Id visitId;
        public Decimal amount;
        public String reason;
        public Id exceptionTransactionId;

        public ExceptionPaymentResponse(Id donorId, Id visitId, Decimal amount, String reason, Id exceptionTransactionId) {
            this.donorId = donorId;
            this.visitId = visitId;
            this.amount = amount;
            this.reason = reason;
            this.exceptionTransactionId = exceptionTransactionId;
        }
    }

    public static List<PromotionPaymentResponse> createPromotionPayment(List<PromotionPaymentRequest> promotionRequests) {
        Map<Id, String> donorIdToAccountNumber = new Map<Id, String>();
        for (PromotionPaymentRequest request : promotionRequests) {
            donorIdToAccountNumber.put(request.donorId, null);
        }

        for(Payment_Method__c activePaymentMethod : [SELECT Id, Account_Number__c, Donor__c FROM Payment_Method__c WHERE Donor__c IN :donorIdToAccountNumber.keySet() AND Is_Active__c = true]) {
            donorIdToAccountNumber.put(activePaymentMethod.Donor__c, activePaymentMethod.Account_Number__c);
        }
        
        Map<PromotionPaymentRequest, Transaction__c> promotionPaymentRequestToTransaction = new Map<PromotionPaymentRequest, Transaction__c>();
        Map<PromotionPaymentRequest, List<Txn_Line_Item__c>> promotionPaymentRequestToTxnLineItems = new Map<PromotionPaymentRequest, List<Txn_Line_Item__c>>();

        for (PromotionPaymentRequest request : promotionRequests) {
            promotionPaymentRequestToTransaction.put(request, new Transaction__c(
                Donor__c = request.donorId,
                Visit__c = request.visitId,
                Type__c = 'Credit',
                SubType__c = 'Promotion Payment',
                Status__c = 'Complete'
            ));

            promotionPaymentRequestToTxnLineItems.put(request, new List<Txn_Line_Item__c> {
                new Txn_Line_Item__c(
                    Type__c = 'Currency',
                    Unit_Cost__c = request.amount,
                    Item__c = request.reason,
                    Quantity__c = 1
                )
            });
        }

        insert promotionPaymentRequestToTransaction.values();
        
        List<Txn_Line_Item__c> allTxnLineItems = new List<Txn_Line_Item__c>();
        for(PromotionPaymentRequest promotionPaymentRequestWithLineItems : promotionPaymentRequestToTxnLineItems.keySet()) {
            Transaction__c txnRecord = promotionPaymentRequestToTransaction.get(promotionPaymentRequestWithLineItems);
            List<Txn_Line_Item__c> lineItems = promotionPaymentRequestToTxnLineItems.get(promotionPaymentRequestWithLineItems);

            for(Txn_Line_Item__c lineItem : lineItems) {
                lineItem.Transaction__c = txnRecord.Id;
            }

            allTxnLineItems.addAll(lineItems);
        }
        insert allTxnLineItems;

        // Process the payments through Onbe
        List<ProesisAddFundsRequest> addFundsRequest = new List<ProesisAddFundsRequest>();
        List<PromotionPaymentResponse> promotionPaymentResponses = new List<PromotionPaymentResponse>();

        for(Transaction__c updatedTransaction : [
            SELECT Id, Donor__c, Visit__c, Amount_Currency__c, (
                SELECT Id, Unit_Cost__c, Type__c, Item__c 
                FROM Txn_Line_Items__r
            ) 
            FROM Transaction__c 
            WHERE Id IN :promotionPaymentRequestToTransaction.values()
        ]) {
            ProesisAddFundsRequest newRequest = new ProesisAddFundsRequest(
                updatedTransaction.Donor__c, updatedTransaction.Visit__c, donorIdToAccountNumber.get(updatedTransaction.Donor__c), 'Promotion Payment'
            );

            for(Txn_Line_Item__c lineItem : updatedTransaction.Txn_Line_Items__r) {
                newRequest.comments.add(lineItem.Item__c);
                newRequest.addLineItem(lineItem.Item__c, lineItem.Type__c, lineItem.Unit_Cost__c);
            }
            
            addFundsRequest.add(newRequest);
            promotionPaymentResponses.add(new PromotionPaymentResponse(
                updatedTransaction.Donor__c, updatedTransaction.Visit__c, updatedTransaction.Amount_Currency__c, String.join(newRequest.comments, ', '), updatedTransaction.Id
            ));
        }

        Database.executeBatch(new AddFundsBatchable(addFundsRequest), 100);
        return promotionPaymentResponses;
    }

    public class PromotionPaymentRequest {
        public Id donorId;
        public Id visitId;
        public Decimal amount;
        public String reason;

        public PromotionPaymentRequest(Id donorId, Id visitId, Decimal amount, String reason) {
            this.donorId = donorId;
            this.visitId = visitId;
            this.amount = amount;
            this.reason = reason;
        }
    }

    public class PromotionPaymentResponse {
        public Id donorId;
        public Id visitId;
        public Decimal amount;
        public String reason;
        public Id promotionTransactionId;

        public PromotionPaymentResponse(Id donorId, Id visitId, Decimal amount, String reason, Id promotionTransactionId) {
            this.donorId = donorId;
            this.visitId = visitId;
            this.amount = amount;
            this.reason = reason;
            this.promotionTransactionId = promotionTransactionId;
        }
    }

    public class DonorPaymentException extends Exception { }
}