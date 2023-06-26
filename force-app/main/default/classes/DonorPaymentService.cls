public with sharing class DonorPaymentService {
    public static List<DonationPaymentResponse> createDonationPayment(List<DonationPaymentRequest> paymentRequests) {
        Set<Id> donorIds = new Set<Id>();

        for (DonationPaymentRequest donationPaymentRequest : paymentRequests) {
            donorIds.add(donationPaymentRequest.donorId);
        }

        Map<Id, String> donorIdToPaymentMethodAccountNumber = new Map<Id, String>();
        for(Payment_Method__c paymentMethod : [
            SELECT Id, Account_Number__c, Donor__c
            FROM Payment_Method__c
            WHERE Donor__c IN :donorIds AND
                Is_Active__c = true AND 
                isDefault__c = true
        ]) {
            donorIdToPaymentMethodAccountNumber.put(paymentMethod.Donor__c, paymentMethod.Account_Number__c);
        }

        Map<DonationPaymentRequest, Transaction__c> donationPaymentRequestToTransaction = new Map<DonationPaymentRequest, Transaction__c>();
        Map<DonationPaymentRequest, List<Txn_Line_Item__c>> donationPaymentRequestToTxnLineItems = new Map<DonationPaymentRequest, List<Txn_Line_Item__c>>();

        for(DonationPaymentRequest paymentRequest : paymentRequests) {
            donationPaymentRequestToTransaction.put(paymentRequest, new Transaction__c(
                Donor__c = paymentRequest.donorId,
                Visit__c = paymentRequest.visitId,
                Type__c = 'Credit',
                SubType__c = 'Donation Payment'
            ));

            List<Txn_Line_Item__c> donationPaymentLineItems = new List<Txn_Line_Item__c>();
            for(DonationPaymentLineItem lineItem : paymentRequest.donationLineItems) {
                donationPaymentLineItems.add(new Txn_Line_Item__c(
                    Item__c = lineItem.description,
                    Quantity__c = 1,
                    Unit_Cost__c = lineItem.unitCost,
                    Type__c = lineItem.type
                ));
            }

            donationPaymentRequestToTxnLineItems.put(paymentRequest, donationPaymentLineItems);
        }

        insert donationPaymentRequestToTransaction.values();

        List<DonationPaymentResponse> donationPaymentResponses = new List<DonationPaymentResponse>();
        List<Txn_Line_Item__c> allLineItems = new List<Txn_Line_Item__c>();

        for(DonationPaymentRequest paymentRequest : paymentRequests) {
            Transaction__c transactionRecord = donationPaymentRequestToTransaction.get(paymentRequest);
            List<Txn_Line_Item__c> donationPaymentLineItems = donationPaymentRequestToTxnLineItems.get(paymentRequest);

            for(Txn_Line_Item__c lineItem : donationPaymentLineItems) {
                lineItem.Transaction__c = transactionRecord.Id;
            }

            allLineItems.addAll(donationPaymentLineItems);

            Decimal totalCurrencyPaid = 0;
            Decimal totalPointsPaid = 0;

            for(Txn_Line_Item__c lineItem : donationPaymentLineItems) {
                if (lineItem.Type__c == 'Currency') {
                    totalCurrencyPaid += lineItem.Unit_Cost__c * lineItem.Quantity__c;
                } else if (lineItem.Type__c == 'Points') {
                    totalPointsPaid += lineItem.Unit_Cost__c * lineItem.Quantity__c;
                }
            }

            donationPaymentResponses.add(new DonationPaymentResponse(
                paymentRequest.donorId,
                paymentRequest.visitId,
                transactionRecord.Id,
                totalCurrencyPaid,
                totalPointsPaid
            ));
        }

        insert allLineItems;
        return donationPaymentResponses;
    }

    public class DonationPaymentRequest {
        public Id donorId;
        public Id visitId;

        public List<DonationPaymentLineItem> donationLineItems = new List<DonationPaymentLineItem>();

        public DonationPaymentRequest(Id donorId, Id visitId) {
            this.donorId = donorId;
            this.visitId = visitId;

            donationLineItems = new List<DonationPaymentLineItem>();
        }

        public void addDonationLineItem(String description, String type, Decimal unitCost) {
            donationLineItems.add(new DonationPaymentLineItem(description, type, unitCost));
        }
    }

    public class DonationPaymentLineItem {
        public String description;
        public String type;
        public Decimal unitCost;

        public DonationPaymentLineItem(String description, String type, Decimal unitCost) {
            this.description = description;
            this.type = type;
            this.unitCost = unitCost;
        }
    }

    public class DonationPaymentResponse {
        public Id donorId;
        public Id visitId;
        public Id transactionId;

        public Decimal totalCurrencyPaid;
        public Decimal totalPointsPaid;

        public DonationPaymentResponse(Id donorId, Id visitId, Id transactionId, Decimal totalCurrencyPaid, Decimal totalPointsPaid) {
            this.donorId = donorId;
            this.visitId = visitId;
            this.transactionId = transactionId;
            this.totalCurrencyPaid = totalCurrencyPaid;
            this.totalPointsPaid = totalPointsPaid;
        }
    }

    public static List<ExceptionPaymentResponse> createExceptionPayment(List<ExceptionPaymentRequest> exceptionRequests) {
        List<DonorCompInvocable.AddFundsRequest> addFundsRequests = new List<DonorCompInvocable.AddFundsRequest>();
        
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

            DonorCompInvocable.AddFundsRequest addFundsRequest = new DonorCompInvocable.AddFundsRequest(
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
        List<DonorCompInvocable.AddFundsRequest> addFundsRequest = new List<DonorCompInvocable.AddFundsRequest>();
        List<PromotionPaymentResponse> promotionPaymentResponses = new List<PromotionPaymentResponse>();

        for(Transaction__c updatedTransaction : [
            SELECT Id, Donor__c, Visit__c, Amount_Currency__c, (
                SELECT Id, Unit_Cost__c, Type__c, Item__c 
                FROM Txn_Line_Items__r
            ) 
            FROM Transaction__c 
            WHERE Id IN :promotionPaymentRequestToTransaction.values()
        ]) {
            DonorCompInvocable.AddFundsRequest newRequest = new DonorCompInvocable.AddFundsRequest(
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