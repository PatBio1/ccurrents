public without sharing class AddFundsBatchable implements Database.Batchable<DonorCompInvocable.AddFundsRequest>, Database.AllowsCallouts {
    List<DonorCompInvocable.AddFundsRequest> addFundRequests;

    public AddFundsBatchable(List<DonorCompInvocable.AddFundsRequest> addFundRequests) {
        this.addFundRequests = addFundRequests;
    }

    public Iterable<DonorCompInvocable.AddFundsRequest> start(Database.BatchableContext bc) {
        return this.addFundRequests;
    }

    public void execute(Database.BatchableContext info, List<DonorCompInvocable.AddFundsRequest> scope) {
        OnbePaymentService paymentService = new OnbePaymentService();

        for(DonorCompInvocable.AddFundsRequest addFundsRequest : scope) {
            String completeComment = String.join(addFundsRequest.comments, ', ');
            if (completeComment.length() > 128) {
                completeComment = completeComment.leftPad(125, '...');
            }

            // We are multiplying by 100 because the payment service expects the amount in cents
            paymentService.processPayment(addFundsRequest.accountNumber, completeComment, (Long)(addFundsRequest.total * 100));
        }
    }

    public void finish(Database.BatchableContext bc) { }
}