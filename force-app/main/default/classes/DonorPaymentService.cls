public with sharing class DonorPaymentService {
    // All these methods have been implemented in various other classes for Onbe
    // Any future payment provider methods should be implemented here

    public static void createDonationPayment(Id donorId, Id visitId) {

    }

    public static void createExceptionPayment(List<DonationService.DonationExceptionRequest> exceptionRequests) {
        DonationService.createExceptionTransactions(exceptionRequests);
    }

    public static List<PromotionPaymentInvocable.PromotionPaymentResponse> createPromotionPayment(List<PromotionPaymentInvocable.PromotionPaymentRequest> promotionRequests) {
        Map<Id, String> donorIdToAccountNumber = new Map<Id, String>();
        for (PromotionPaymentInvocable.PromotionPaymentRequest request : promotionRequests) {
            donorIdToAccountNumber.put(request.donorId, null);
        }

        for(Payment_Method__c activePaymentMethod : [SELECT Id, Account_Number__c, Donor__c FROM Payment_Method__c WHERE Donor__c IN :donorIdToAccountNumber.keySet() AND Is_Active__c = true]) {
            donorIdToAccountNumber.put(activePaymentMethod.Donor__c, activePaymentMethod.Account_Number__c);
        }
        
        Map<PromotionPaymentInvocable.PromotionPaymentRequest, Transaction__c> promotionPaymentRequestToTransaction = new Map<PromotionPaymentInvocable.PromotionPaymentRequest, Transaction__c>();
        Map<PromotionPaymentInvocable.PromotionPaymentRequest, List<Txn_Line_Item__c>> promotionPaymentRequestToTxnLineItems = new Map<PromotionPaymentInvocable.PromotionPaymentRequest, List<Txn_Line_Item__c>>();

        for (PromotionPaymentInvocable.PromotionPaymentRequest request : promotionRequests) {
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
        for(PromotionPaymentInvocable.PromotionPaymentRequest promotionPaymentRequestWithLineItems : promotionPaymentRequestToTxnLineItems.keySet()) {
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
        List<PromotionPaymentInvocable.PromotionPaymentResponse> promotionPaymentResponses = new List<PromotionPaymentInvocable.PromotionPaymentResponse>();

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
            
            PromotionPaymentInvocable.PromotionPaymentResponse promotionResponse = new PromotionPaymentInvocable.PromotionPaymentResponse();
            promotionResponse.donorId = updatedTransaction.Donor__c;
            promotionResponse.visitId = updatedTransaction.Visit__c;
            promotionResponse.amount = updatedTransaction.Amount_Currency__c;
            promotionResponse.reason = String.join(newRequest.comments, ', ');
            promotionResponse.transactionId = updatedTransaction.Id;

            addFundsRequest.add(newRequest);
            promotionPaymentResponses.add(promotionResponse);
        }

        Database.executeBatch(new AddFundsBatchable(addFundsRequest), 100);
        return promotionPaymentResponses;
    }
}