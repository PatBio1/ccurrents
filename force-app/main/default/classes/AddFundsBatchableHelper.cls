public without sharing class AddFundsBatchableHelper {
    public static Map<DonorCompInvocable.AddFundsRequest, Transaction__c> createDebitTransactions(List<DonorCompInvocable.AddFundsRequest> requests) {
        Map<DonorCompInvocable.AddFundsRequest, Transaction__c> addFundsRequestToTransaction = new Map<DonorCompInvocable.AddFundsRequest, Transaction__c>();
        Map<Id, Transaction__c> existingTransactions = new Map<Id, Transaction__c>();

        for(DonorCompInvocable.AddFundsRequest addFundsRequest : requests) {
            Transaction__c debitTransaction = new Transaction__c();
            debitTransaction.Type__c = 'Debit';
            debitTransaction.SubType__c = addFundsRequest.transactionSubType;
            debitTransaction.Status__c = 'Processing';
            debitTransaction.Donor__c = addFundsRequest.donorContactId;
            debitTransaction.Service__c = 'OnbePaymentService';

            if (addFundsRequest.visitId != null) {
                debitTransaction.Visit__c = addFundsRequest.visitId;
            }

            if (addFundsRequest.isExceptionPayment) {
                debitTransaction.SubType__c = 'Exception';
            }

            if (addFundsRequest.existingDebitTransactionId != null) {
                debitTransaction.Id = addFundsRequest.existingDebitTransactionId;
                existingTransactions.put(addFundsRequest.existingDebitTransactionId, debitTransaction);
            } else {
                debitTransaction.Retry_Count__c = 0;
            }

            addFundsRequestToTransaction.put(addFundsRequest, debitTransaction);
        }

        for(Transaction__c exisitingTransaction : [SELECT Id, Retry_Count__c, Retry_Next__c FROM Transaction__c WHERE Id IN :existingTransactions.keySet()]) {
            existingTransactions.get(exisitingTransaction.Id).Retry_Count__c = exisitingTransaction.Retry_Count__c + 1;
            existingTransactions.get(exisitingTransaction.Id).Retry_Next__c = exisitingTransaction.Retry_Next__c;
        }

        return addFundsRequestToTransaction;
    }
    
    public static Map<DonorCompInvocable.AddFundsRequest, List<Txn_Line_Item__c>> createDebitTransactionLineItems(List<DonorCompInvocable.AddFundsRequest> addFundsRequests) {
        Map<DonorCompInvocable.AddFundsRequest, List<Txn_Line_Item__c>> debitTransactionIdToLineItem = new Map<DonorCompInvocable.AddFundsRequest, List<Txn_Line_Item__c>>();

        for(DonorCompInvocable.AddFundsRequest addFundsRequest : addFundsRequests) {
            List<Txn_Line_Item__c> debitTransactionLineItems = new List<Txn_Line_Item__c>();
            
            for(DonorCompInvocable.AddFundsLineItem lineItem : addFundsRequest.lineItems) {
                debitTransactionLineItems.add(new Txn_Line_Item__c(
                    Type__c = lineItem.type,
                    Unit_Cost__c = lineItem.amount,
                    Quantity__c = lineItem.quantity,
                    Item__c = lineItem.item
                ));
            }

            debitTransactionIdToLineItem.put(addFundsRequest, debitTransactionLineItems);
        }

        return debitTransactionIdToLineItem;
    }

    public static void processAddFundsCallouts(List<DonorCompInvocable.AddFundsRequest> requests) {
        OnbePaymentService paymentService = new OnbePaymentService();
        
        for(DonorCompInvocable.AddFundsRequest addFundsRequest : requests) {
            if (String.isEmpty(addFundsRequest.accountNumber)) {
                addFundsRequest.recordAPIResponse(false, 'Donor does not have an active payment method to process this transaction.');
                continue;
            }

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
        Map<DonorCompInvocable.AddFundsRequest, List<Txn_Line_Item__c>> addFundsRequestToTxnLineItem,
        Boolean isRetry
    ) {
        Proesis_Settings__c proesisSettings = Proesis_Settings__c.getOrgDefaults();

        Decimal baseRetryTime = proesisSettings.Payment_Service_Base_Retry__c;
        if (baseRetryTime == null) {
            baseRetryTime = 600;
        }

        Decimal multiplier = proesisSettings.Payment_Service_Multiplier__c;
        if (multiplier == null) {
            multiplier = 1.4;
        }

        // Transaction
        for(DonorCompInvocable.AddFundsRequest request : addFundsRequestToTransaction.keySet()) {
            Transaction__c transactionRecord = addFundsRequestToTransaction.get(request);
            transactionRecord.Status__c = (request.isSuccessfullyProcessed) ? 'Complete' : 'Error';

            if (!request.isSuccessfullyProcessed) {
                Datetime nextRetryDatetime = System.now();
                nextRetryDatetime = nextRetryDatetime.addSeconds((Integer)(baseRetryTime * Math.pow((Double)multiplier, (Double)transactionRecord.Retry_Count__c)));

                transactionRecord.Retry_Next__c = nextRetryDatetime;
            }
        }

        try {
            upsert addFundsRequestToTransaction.values();
        } catch (Exception e) {
            System.debug('Error updating debit transactions: ' + e.getMessage());
        }

        // Transaction Line Item
        if (!isRetry) {
            List<Txn_Line_Item__c> txnLineItemsToInsert = new List<Txn_Line_Item__c>();

            for(DonorCompInvocable.AddFundsRequest request : addFundsRequestToTxnLineItem.keySet()) {
                for(Txn_Line_Item__c txnLineItem : addFundsRequestToTxnLineItem.get(request)) {
                    txnLineItem.Transaction__c = addFundsRequestToTransaction.get(request).Id;
                    txnLineItemsToInsert.add(txnLineItem);
                }
            }

            insert txnLineItemsToInsert;
        }

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
            }
        }
    }
}