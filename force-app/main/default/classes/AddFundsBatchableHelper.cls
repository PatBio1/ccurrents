public with sharing class AddFundsBatchableHelper {
    public static Map<DonorCompInvocable.AddFundsRequest, Transaction__c> createDebitTransactions(List<DonorCompInvocable.AddFundsRequest> requests) {
        Map<DonorCompInvocable.AddFundsRequest, Transaction__c> addFundsRequestToTransaction = new Map<DonorCompInvocable.AddFundsRequest, Transaction__c>();

        for(DonorCompInvocable.AddFundsRequest addFundsRequest : requests) {
            Transaction__c debitTransaction = new Transaction__c();
            debitTransaction.Type__c = 'Debit';
            debitTransaction.Status__c = 'Processing';
            debitTransaction.Donor__c = addFundsRequest.donorContactId;
            debitTransaction.Visit__c = addFundsRequest.visitId;
            addFundsRequestToTransaction.put(addFundsRequest, debitTransaction);
        }

        return addFundsRequestToTransaction;
    }
    
    public static Map<DonorCompInvocable.AddFundsRequest, Txn_Line_Item__c> createDebitTransactionLineItems(List<DonorCompInvocable.AddFundsRequest> addFundsRequests) {
        Map<DonorCompInvocable.AddFundsRequest, Txn_Line_Item__c> debitTransactionIdToLineItem = new Map<DonorCompInvocable.AddFundsRequest, Txn_Line_Item__c>();

        for(DonorCompInvocable.AddFundsRequest addFundsRequest : addFundsRequests) {
            debitTransactionIdToLineItem.put(addFundsRequest, new Txn_Line_Item__c(
                Type__c = 'Currency',
                Unit_Cost__c = addFundsRequest.total,
                Quantity__c = 1,
                Item__c = 'Donation Payment'
            ));
        }

        return debitTransactionIdToLineItem;
    }

    public static void processAddFundsCallouts(List<DonorCompInvocable.AddFundsRequest> requests) {
        OnbePaymentService paymentService = new OnbePaymentService();
        
        for(DonorCompInvocable.AddFundsRequest addFundsRequest : requests) {
            String completeComment = String.join(addFundsRequest.comments, ', ');
            if (completeComment.length() > 128) {
                completeComment = completeComment.leftPad(125, '...');
            }

            // We are multiplying by 100 because the payment service expects the amount in cents
            try {
                paymentService.processPayment(addFundsRequest.accountNumber, completeComment, (Long)(addFundsRequest.total * 100));
                addFundsRequest.recordAPIResponse(true, '');
            } catch(Exception e) {
                System.debug('Error processing payment: ' + e.getMessage());
                addFundsRequest.recordAPIResponse(false, e.getMessage());
            }
            
        }
    }
    
    public static void handleAddFundsResponses(
        Map<DonorCompInvocable.AddFundsRequest, Transaction__c> addFundsRequestToTransaction,
        Map<DonorCompInvocable.AddFundsRequest, Txn_Line_Item__c> addFundsRequestToTxnLineItem
    ) {
        // Transaction
        for(DonorCompInvocable.AddFundsRequest request : addFundsRequestToTransaction.keySet()) {
            Transaction__c transactionRecord = addFundsRequestToTransaction.get(request);

            transactionRecord.Status__c = (request.isSuccessfullyProcessed) ? 'Complete' : 'Error';
            transactionRecord.Service__c = 'Onbe';
        }

        try {
            insert addFundsRequestToTransaction.values();
        } catch (Exception e) {
            System.debug('Error updating debit transactions: ' + e.getMessage());
            throw e;
        }

        // Transaction Line Item
        for(DonorCompInvocable.AddFundsRequest request : addFundsRequestToTxnLineItem.keySet()) {
            Txn_Line_Item__c txnLineItemRecord = addFundsRequestToTxnLineItem.get(request);
            txnLineItemRecord.Transaction__c = addFundsRequestToTransaction.get(request).Id;
        }
        insert addFundsRequestToTxnLineItem.values();

        // Transaction Log
        List<Transaction_Log__c> transactionLogs = new List<Transaction_Log__c>();

        for(DonorCompInvocable.AddFundsRequest request : addFundsRequestToTransaction.keySet()) {
            Transaction__c transactionRecord = addFundsRequestToTransaction.get(request);

            if (!request.isSuccessfullyProcessed) {
                transactionLogs.add(new Transaction_Log__c(
                    Transaction__c = transactionRecord.Id,
                    Datetime__c = System.now(),
                    Message__c = request.processResponse,
                    Payment_Service__c = 'Onbe'
                ));
            }
        }

        if (transactionLogs.size() > 0) {
            try {
                insert transactionLogs;
            } catch (Exception e) {
                System.debug('Error inserting transaction logs: ' + e.getMessage());
                throw e;
            }
        }
    }
}