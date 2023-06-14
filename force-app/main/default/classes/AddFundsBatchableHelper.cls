public without sharing class AddFundsBatchableHelper {
    @TestVisible
    private static Boolean throwSalesforceException = false;
    
    public static void createDebitTransactionsWithLineItems(List<DonorCompInvocable.AddFundsRequest> requests) {
        Map<DonorCompInvocable.AddFundsRequest, Transaction__c> addFundsRequestToTransaction = new Map<DonorCompInvocable.AddFundsRequest, Transaction__c>();
        Map<DonorCompInvocable.AddFundsRequest, List<Txn_Line_Item__c>> debitTransactionIdToLineItem = new Map<DonorCompInvocable.AddFundsRequest, List<Txn_Line_Item__c>>();

        for(DonorCompInvocable.AddFundsRequest addFundsRequest : requests) {
            // Transactions
            Transaction__c debitTransaction = new Transaction__c();
            debitTransaction.Type__c = 'Debit';
            debitTransaction.SubType__c = addFundsRequest.transactionSubType;
            debitTransaction.Status__c = 'Processing';
            debitTransaction.Donor__c = addFundsRequest.donorContactId;
            debitTransaction.Service__c = 'OnbePaymentService';
            debitTransaction.Retry_Count__c = 0;

            if (addFundsRequest.visitId != null) {
                debitTransaction.Visit__c = addFundsRequest.visitId;
            }

            addFundsRequestToTransaction.put(addFundsRequest, debitTransaction);

            // Line Items
            List<Txn_Line_Item__c> debitTransactionLineItems = new List<Txn_Line_Item__c>();

            for(DonorCompInvocable.AddFundsLineItem lineItem : addFundsRequest.lineItems) {
                if (lineItem.type == 'Points' && addFundsRequest.transactionSubType != 'Point Redemption') {
                    continue;
                }

                debitTransactionLineItems.add(new Txn_Line_Item__c(
                    Type__c = lineItem.type,
                    Unit_Cost__c = lineItem.amount,
                    Quantity__c = lineItem.quantity,
                    Item__c = lineItem.item
                ));
            }

            debitTransactionIdToLineItem.put(addFundsRequest, debitTransactionLineItems);
        }
        insert addFundsRequestToTransaction.values();

        // Parent line items to transactions
        List<Txn_Line_Item__c> lineItemsToInsert = new List<Txn_Line_Item__c>();
        for(DonorCompInvocable.AddFundsRequest addFundsRequest : debitTransactionIdToLineItem.keySet()) {
            Transaction__c transactionRecord = addFundsRequestToTransaction.get(addFundsRequest);
            addFundsRequest.debitTransactionId = transactionRecord.Id;

            for(Txn_Line_Item__c lineItem : debitTransactionIdToLineItem.get(addFundsRequest)) {
                lineItem.Transaction__c = transactionRecord.Id;
            }

            lineItemsToInsert.addAll(debitTransactionIdToLineItem.get(addFundsRequest));
        }
        insert lineItemsToInsert;
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
                // Using this instead of TestUtils.throwException as we need a separate boolean for this class to control this exception indendently
                // TestUtils.throwException is already being used to surpress Onbe Exceptions in the payment service class
                if (throwSalesforceException) {
                    Util.testExceptionHandling();
                }

                String onbeTransactionId = (String.isEmpty(addFundsRequest.existingOnbeTransactionId)) ? addFundsRequest.debitTransactionId + '-' + String.valueOf(System.currentTimeMillis()) : addFundsRequest.existingOnbeTransactionId;
                String message = paymentService.processPayment(addFundsRequest.accountNumber, completeComment, (Long)(addFundsRequest.total * 100), onbeTransactionId);

                if (message == Constants.ONBE_ACCOUNT_MANAGEMENT_PROCESSING_STATUS) {
                    addFundsRequest.recordAPIResponse(false, 'Payment is still processing.');
                    addFundsRequest.setOnbeTransactionId(onbeTransactionId); // Setting transactions id to ensure we grab this transaction again, should only be done with 2 code
                    continue;
                }

                addFundsRequest.recordAPIResponse(true, '');
                addFundsRequest.setOnbeTransactionId(null); // Setting transaction id to null to ensure we don't reuse the transaction
            } catch(OnbePaymentService.OnbeServiceException onbeError) {
                System.debug('Error processing payment: ' + onbeError.getMessage());

                addFundsRequest.recordAPIResponse(false, onbeError.getMessage());
                addFundsRequest.setOnbeTransactionId(null); // Setting transaction id to null to ensure we don't reuse the transaction
            } catch(Exception e) {
                // If we get a Salesforce exception, we don't wanna queue the transaction up for a retry... in case the Onbe transaction did get processed
                addFundsRequest.recordAPIResponse(true, 'Salesforce Exception - ' + e.getMessage());
                addFundsRequest.setOnbeTransactionId(null); // Setting transaction id to null to ensure we don't reuse the transaction
            }
        }
    }
    
    public static void handleAddFundsResponses(List<DonorCompInvocable.AddFundsRequest> requests) {
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
        Map<Id, DonorCompInvocable.AddFundsRequest> transactionIdToAddFundsRequest = new Map<Id, DonorCompInvocable.AddFundsRequest>();
        for(DonorCompInvocable.AddFundsRequest request : requests) {
            transactionIdToAddFundsRequest.put(request.debitTransactionId, request);
        }

        List<Transaction__c> transactionsToUpdate = new List<Transaction__c>();
        List<Transaction_Log__c> transactionLogs = new List<Transaction_Log__c>();

        for(Transaction__c transactionRecord : [SELECT Id, Retry_Count__c, Retry_Next__c, Onbe_Transaction_Id__c FROM Transaction__c WHERE Id IN :transactionIdToAddFundsRequest.keySet()]) {
            DonorCompInvocable.AddFundsRequest request = transactionIdToAddFundsRequest.get(transactionRecord.Id);

            // Transaction
            transactionRecord.Status__c = (request.isSuccessfullyProcessed) ? 'Complete' : 'Error';
            transactionRecord.Onbe_Transaction_Id__c = request.existingOnbeTransactionId; // Even if the onbeTransaction is null we want to set this, a null onbeTransactionId indicates that the transaction finished processing

            if (!request.isSuccessfullyProcessed) {
                Datetime nextRetryDatetime = System.now();
                nextRetryDatetime = nextRetryDatetime.addSeconds((Integer)(baseRetryTime * Math.pow((Double)multiplier, (Double)transactionRecord.Retry_Count__c)));

                transactionRecord.Retry_Count__c = transactionRecord.Retry_Count__c + 1;
                transactionRecord.Retry_Next__c = nextRetryDatetime;
            }

            transactionsToUpdate.add(transactionRecord);

            // Transaction Log
            if (!String.isEmpty(request.processResponse)) {
                transactionLogs.add(new Transaction_Log__c(
                    Transaction__c = transactionRecord.Id,
                    Datetime__c = System.now(),
                    Message__c = request.processResponse,
                    Payment_Service__c = 'OnbePaymentService'
                ));
            }
        }

        try {
            update transactionsToUpdate;
        } catch (Exception e) {
            System.debug('Error updating debit transactions: ' + e.getMessage());
        }

        try {
            insert transactionLogs;
        } catch (Exception e) {
            System.debug('Error inserting transaction logs: ' + e.getMessage());
        }
    }
}