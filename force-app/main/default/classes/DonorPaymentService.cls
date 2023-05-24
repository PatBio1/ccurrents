public with sharing class DonorPaymentService {
    // All these methods have been implemented in various other classes for Onbe
    // Any future payment provider methods should be implemented here

    public static void createDonationPayment(Id donorId, Id visitId) {

    }

    public static void createExceptionPayment(List<DonationService.DonationExceptionRequest> exceptionRequests) {
        DonationService.createExceptionTransactions(exceptionRequests);
    }

    public static void createPromotionPayment(List<PromotionPaymentRequest> promotionRequests) {
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
        for(Transaction__c updatedTransaction : [
            SELECT Id, Donor__c, Visit__c, (
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
        }

        Database.executeBatch(new AddFundsBatchable(addFundsRequest), 100);
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
}