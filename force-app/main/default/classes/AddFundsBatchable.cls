public without sharing class AddFundsBatchable implements Database.Batchable<DonorCompInvocable.AddFundsRequest>, Database.AllowsCallouts {
    List<DonorCompInvocable.AddFundsRequest> addFundRequests;

    public AddFundsBatchable(List<DonorCompInvocable.AddFundsRequest> addFundRequests) {
        this.addFundRequests = addFundRequests;
    }

    public Iterable<DonorCompInvocable.AddFundsRequest> start(Database.BatchableContext bc) {
        return this.addFundRequests;
    }

    public void execute(Database.BatchableContext info, List<DonorCompInvocable.AddFundsRequest> scope) {
        Map<DonorCompInvocable.AddFundsRequest, Transaction__c> debitTransactions = AddFundsBatchableHelper.createDebitTransactions(scope);
        AddFundsBatchableHelper.createDebitTransactionLineItems(debitTransactions);
        AddFundsBatchableHelper.processAddFundsCallouts(new List<DonorCompInvocable.AddFundsRequest>(debitTransactions.keySet()));

        AddFundsBatchableHelper.handleAddFundsResponses(debitTransactions);
    }

    public void finish(Database.BatchableContext bc) { }
}