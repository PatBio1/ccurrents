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

        try {
            insert addFundsRequestToTransaction.values();
        } catch (Exception e) {
            System.debug('Error inserting debit transactions: ' + e.getMessage());
            throw e;
        }

        return addFundsRequestToTransaction;
    }
    
    public static Map<Id, Txn_Line_Item__c> createDebitTransactionLineItems(Map<DonorCompInvocable.AddFundsRequest, Transaction__c> addFundsRequestToTransaction) {
        Map<Id, Txn_Line_Item__c> debitTransactionIdToLineItem = new Map<Id, Txn_Line_Item__c>();

        for(DonorCompInvocable.AddFundsRequest addFundsRequest : addFundsRequestToTransaction.keySet()) {
            Transaction__c transactionRecord = addFundsRequestToTransaction.get(addFundsRequest);
            Txn_Line_Item__c debitLineItem = new Txn_Line_Item__c();

            debitLineItem.Transaction__c = transactionRecord.Id;
            debitLineItem.Type__c = 'Currency';
            debitLineItem.Unit_Cost__c = addFundsRequest.total;
            debitLineItem.Quantity__c = 1;
            debitLineItem.Item__c = 'Donation Payment';

            debitTransactionIdToLineItem.put(transactionRecord.Id, debitLineItem);
        }

        try {
            insert debitTransactionIdToLineItem.values();
        } catch (Exception e) {
            System.debug('Error inserting debit transaction line items: ' + e.getMessage());
            throw e;
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
    
    public static void handleAddFundsResponses(Map<DonorCompInvocable.AddFundsRequest, Transaction__c> addFundsRequestToTransaction) {
        List<Transaction_Log__c> transactionLogs = new List<Transaction_Log__c>();
        
        for(DonorCompInvocable.AddFundsRequest request : addFundsRequestToTransaction.keySet()) {
            Transaction__c transactionRecord = addFundsRequestToTransaction.get(request);

            if (request.isSuccessfullyProcessed) {
                transactionRecord.Status__c = 'Completed';
            } else {
                transactionRecord.Status__c = 'Error';
                transactionLogs.add(new Transaction_Log__c(
                    Transaction__c = transactionRecord.Id,
                    Datetime__c = System.now(),
                    Message__c = request.processResponse,
                    Payment_Service__c = 'Onbe'
                ));
            }
        }

        try {
            update addFundsRequestToTransaction.values();
        } catch (Exception e) {
            System.debug('Error updating debit transactions: ' + e.getMessage());
            throw e;
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