public without sharing class TransactionActionController {
    @AuraEnabled
    public static Transaction__c markTransactionForRetry(Id transactionId) {
        Transaction__c transactionToRetry = new Transaction__c(
            Id = transactionId,
            Retry_Count__c = 0,
            Retry_Next__c = null
        );

        try {
            update transactionToRetry;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        if (AddFundsBatchable.getScheduledRetryJobInstanceCount() == 0) {
            AddFundsBatchable.scheduledRetryRun();
        }

        return transactionToRetry;
    }

    @AuraEnabled
    public static Transaction__c markTransactionAsManualPayment(Id transactionId) {
        Transaction__c manualTransaction = new Transaction__c(
            Id = transactionId,
            Was_Manually_Processed__c = true,
            Status__c = 'Complete'
        );
        
        try {
            update manualTransaction;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return manualTransaction;
    }
}