public without sharing class AddFundsBatchable implements System.Schedulable, Database.Batchable<DonorCompInvocable.AddFundsRequest>, Database.AllowsCallouts, Database.Stateful {
    List<DonorCompInvocable.AddFundsRequest> addFundRequests;
    Boolean isRetry;

    // IF no specific requests are passed in, then we will look for any Add Funds Requests awaiting retry
    public AddFundsBatchable() {
        this.addFundRequests = null;
        this.isRetry = true;
    }

    public AddFundsBatchable(List<DonorCompInvocable.AddFundsRequest> addFundRequests) {
        this.addFundRequests = addFundRequests;
        this.isRetry = false;
    }

    public Iterable<DonorCompInvocable.AddFundsRequest> start(Database.BatchableContext bc) {
        Proesis_Settings__c proesisSettings = Proesis_Settings__c.getOrgDefaults();
        Decimal paymentServiceMaxRetry = proesisSettings.Payment_Service_Max_Retry__c;

        if (paymentServiceMaxRetry == null) {
            paymentServiceMaxRetry = 10; // default per model provided by Tim
        }
        
        if (this.addFundRequests == null || this.addFundRequests.size() == 0) {
            this.addFundRequests = new List<DonorCompInvocable.AddFundsRequest>();
            Map<Id, String> donorIdToActivePaymentMethodNumber = new Map<Id, String>();

            for(Payment_Method__c paymentMethod : [
                SELECT Id, Donor__c, Account_Number__c
                FROM Payment_Method__c
                WHERE Is_Active__c = true AND
                    isDefault__c = true AND 
                    Donor__c IN (
                        SELECT Donor__c 
                        FROM Transaction__c 
                        WHERE Status__c = 'Error' AND 
                            Type__c = 'Debit' AND 
                            (Retry_Next__c = null OR Retry_Next__c <= TODAY) AND
                            (Retry_Count__c = null OR Retry_Count__c < :paymentServiceMaxRetry)
                    )
            ]) {
                donorIdToActivePaymentMethodNumber.put(paymentMethod.Donor__c, paymentMethod.Account_Number__c);
            }

            for(Transaction__c erroredTransaction : [
                SELECT Id, Donor__c, Visit__c, SubType__c
                FROM Transaction__c 
                WHERE Status__c = 'Error' AND 
                    Type__c = 'Debit' AND 
                    (Retry_Next__c = null OR Retry_Next__c <= TODAY) AND 
                    (Retry_Count__c = null OR Retry_Count__c < :paymentServiceMaxRetry)
            ]) {
                this.addFundRequests.add(new DonorCompInvocable.AddFundsRequest(
                    erroredTransaction.Donor__c,
                    erroredTransaction.Visit__c,
                    donorIdToActivePaymentMethodNumber.get(erroredTransaction.Donor__c),
                    erroredTransaction.SubType__c,
                    erroredTransaction.Id
                ));
            }
        }

        return this.addFundRequests;
    }

    public void execute(SchedulableContext sc) {
        // Callout limit is 100 per async transaction, therefore no more than 100 records
        // A scheduled run also assumes that we are only retrying errored transactions
        Database.executeBatch(new AddFundsBatchable(), 100);
    }

    public void execute(Database.BatchableContext info, List<DonorCompInvocable.AddFundsRequest> scope) {
        Map<DonorCompInvocable.AddFundsRequest, Transaction__c> debitTransactions = AddFundsBatchableHelper.createDebitTransactions(scope);
        Map<DonorCompInvocable.AddFundsRequest, List<Txn_Line_Item__c>> transactionLineItems;

        if (!isRetry) {
            transactionLineItems = AddFundsBatchableHelper.createDebitTransactionLineItems(scope);
        }

        AddFundsBatchableHelper.processAddFundsCallouts(scope);
        AddFundsBatchableHelper.handleAddFundsResponses(debitTransactions, transactionLineItems, isRetry);
    }

    public void finish(Database.BatchableContext bc) { }
}