public without sharing class DonationService {
    public static void createExceptionTransaction(DonationExceptionRequest exceptionRequest) {
        createExceptionTransactions(new List<DonationExceptionRequest>{ exceptionRequest });
    }

    public static void createExceptionTransactions(List<DonationExceptionRequest> exceptionRequests) {
        List<ProesisAddFundsRequest> addFundsRequests = new List<ProesisAddFundsRequest>();
        
        Set<Id> exceptionRateIds = new Set<Id>();
        Set<Id> visitIds = new Set<Id>();

        for (DonationExceptionRequest exceptionRequest : exceptionRequests) {
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

        for (DonationExceptionRequest exceptionRequest : exceptionRequests) {
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
                throw new CreateExceptionPaymentException(String.format(Constants.CENTER_DAY_EXCEPTION_LIMIT_ERROR, new List<object> { center.Name }));
            }

            if ((center.Individual_Exception_Limit__c != null && center.Individual_Exception_Limit__c > 0) && exceptionAmount > center.Individual_Exception_Limit__c) {
                throw new CreateExceptionPaymentException(String.format(Constants.CENTER_INDIVIDUAL_EXCEPTION_LIMIT_ERROR, new List<object> { center.Name }));
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
        for(DonationExceptionRequest exceptionRequest : exceptionRequests) {
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
        for (DonationExceptionRequest exceptionRequest : exceptionRequests) {
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
            
            Txn_Line_Item__c lineItem = new Txn_Line_Item__c(
                Transaction__c = visitIdToTransaction.get(exceptionRequest.visitId).Id,
                Item__c = exceptionReason,
                Unit_Cost__c = exceptionAmount,
                Quantity__c = 1,
                Type__c = 'Currency'
            );

            lineItems.add(lineItem);
        }
        insert lineItems;

        Database.executeBatch(new AddFundsBatchable(addFundsRequests), 100);
    }

    public class DonationExceptionRequest {
        public Id donorId;
        public Id visitId;
        public Id exceptionRateId;

        public Decimal exceptionAmount;
        public String exceptionReason;

        public DonationExceptionRequest(Id donorId, Id visitId, Id exceptionRateId) {
            this.donorId = donorId;
            this.visitId = visitId;
            this.exceptionRateId = exceptionRateId;
        }

        public DonationExceptionRequest(Id donorId, Id visitId, Decimal amount, String reason) {
            this.donorId = donorId;
            this.visitId = visitId;
            this.exceptionAmount = amount;
            this.exceptionReason = reason;
        }
    }

    public class CreateExceptionPaymentException extends Exception {}
}