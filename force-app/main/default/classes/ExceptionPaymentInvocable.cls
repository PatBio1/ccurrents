public without sharing class ExceptionPaymentInvocable {

    @InvocableMethod(Label='Exception Payment' Category='Payment' Description='Calls Exception Payment in Donor Payment Service.')
    public static List<ExceptionPaymentResponse> invoke(List<ExceptionPaymentRequest> exceptionPaymentRequests) {
        List<DonorPaymentService.ExceptionPaymentRequest> exceptionRequests = new List<DonorPaymentService.ExceptionPaymentRequest>();

        for (ExceptionPaymentRequest exceptionPaymentRequest : exceptionPaymentRequests) {
            exceptionRequests.add(new DonorPaymentService.ExceptionPaymentRequest(
                exceptionPaymentRequest.donorId,
                exceptionPaymentRequest.visitId,
                exceptionPaymentRequest.amount,
                exceptionPaymentRequest.reason
            ));
        }

        List<DonorPaymentService.ExceptionPaymentResponse> exceptionPaymentServiceResponses = DonorPaymentService.createExceptionPayment(exceptionRequests);
        List<ExceptionPaymentResponse> exceptionPaymentResponses = new List<ExceptionPaymentResponse>();

        for (DonorPaymentService.ExceptionPaymentResponse serviceResponse : exceptionPaymentServiceResponses) {
            ExceptionPaymentResponse newResponse = new ExceptionPaymentResponse();

            newResponse.donorId = serviceResponse.donorId;
            newResponse.visitId = serviceResponse.visitId;
            newResponse.amount = serviceResponse.amount;
            newResponse.reason = serviceResponse.reason;
            newResponse.transactionId = serviceResponse.exceptionTransactionId;

            exceptionPaymentResponses.add(newResponse);
        }

        return exceptionPaymentResponses;
    }

    public class ExceptionPaymentRequest {
        @InvocableVariable
        public Id donorId;

        @InvocableVariable
        public Id visitId;

        @InvocableVariable
        public Decimal amount;

        @InvocableVariable
        public String reason;
    }

    public class ExceptionPaymentResponse {
        @InvocableVariable
        public Id donorId;

        @InvocableVariable
        public Id visitId;

        @InvocableVariable
        public Decimal amount;

        @InvocableVariable
        public String reason;

        @InvocableVariable
        public Id transactionId;
    }
}