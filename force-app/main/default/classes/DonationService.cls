public with sharing class DonationService {
    public static void createExceptionTransaction(DonationExceptionRequest exceptionRequest) {
        createExceptionTransactions(new List<DonationExceptionRequest>{ exceptionRequest });
    }

    public static void createExceptionTransactions(List<DonationExceptionRequest> exceptionRequests) {
        Set<Id> exceptionRateIds = new Set<Id>();
        for (DonationExceptionRequest exceptionRequest : exceptionRequests) {
            exceptionRateIds.add(exceptionRequest.exceptionRateId);
        }
        
        Map<Id, Rate__c> exceptionRates = new Map<Id, Rate__c>([SELECT Id, Name, Base_Payment__c, Description__c FROM Rate__c WHERE Id IN :exceptionRateIds]);
        Map<Id, Transaction__c> visitIdToTransaction = new Map<Id, Transaction__c>();
        Map<Id, Task> visitIdToExceptionPaymentTask = new Map<Id, Task>();

        List<Group> targetExceptionPaymentTaskQueue = [SELECT Id FROM Group WHERE DeveloperName = 'Proesis_Operations' LIMIT 1];
        for(DonationExceptionRequest exceptionRequest : exceptionRequests) {
            Transaction__c exceptionTransaction = new Transaction__c(
                Donor__c = exceptionRequest.donorId,
                Visit__c = exceptionRequest.visitId,
                Status__c = 'New',
                Type__c = 'Credit',
                SubType__c = 'Exception'
            );

            Task exceptionPaymentTask = new Task(
                WhoId = exceptionRequest.donorId,
                WhatId = exceptionRequest.visitId,
                Subject = 'Exception Payment - ' + exceptionRates.get(exceptionRequest.exceptionRateId).Description__c,
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
            Rate__c exceptionRate = exceptionRates.get(exceptionRequest.exceptionRateId);
            Txn_Line_Item__c lineItem = new Txn_Line_Item__c(
                Transaction__c = visitIdToTransaction.get(exceptionRequest.visitId).Id,
                Item__c = exceptionRate.Description__c,
                Unit_Cost__c = exceptionRate.Base_Payment__c,
                Quantity__c = 1,
                Type__c = 'Currency'
            );

            lineItems.add(lineItem);
        }
        insert lineItems;
    }

    public class DonationExceptionRequest {
        public Id donorId;
        public Id visitId;
        public Id exceptionRateId;

        public DonationExceptionRequest(Id donorId, Id visitId, Id exceptionRateId) {
            this.donorId = donorId;
            this.visitId = visitId;
            this.exceptionRateId = exceptionRateId;
        }
    }
}