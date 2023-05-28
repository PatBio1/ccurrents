public without sharing class ExceptionPaymentInvocable {

    @InvocableMethod(Label='Exception Payment' Category='Payment' Description='Calls Exception Payment in Donor Payment Service.')
    public static List<ExceptionPaymentResponse> invoke(List<ExceptionPaymentRequest> exceptionPaymentRequests) {
        List<ExceptionPaymentResponse> exceptionPaymentResponses = new List<ExceptionPaymentResponse>();
        List<DonationService.DonationExceptionRequest> exceptionRequests = new List<DonationService.DonationExceptionRequest>();

        for (ExceptionPaymentRequest exceptionPaymentRequest : exceptionPaymentRequests) {
            exceptionRequests.add(new DonationService.DonationExceptionRequest(
                exceptionPaymentRequest.donorId,
                exceptionPaymentRequest.visitId,
                exceptionPaymentRequest.amount,
                exceptionPaymentRequest.reason
            ));

            ExceptionPaymentResponse exceptionPaymentResponse = new ExceptionPaymentResponse();
            exceptionPaymentResponse.donorId = exceptionPaymentRequest.donorId;
            exceptionPaymentResponse.visitId = exceptionPaymentRequest.visitId;
            exceptionPaymentResponse.amount = exceptionPaymentRequest.amount;
            exceptionPaymentResponse.reason = exceptionPaymentRequest.reason;
            exceptionPaymentResponses.add(exceptionPaymentResponse);
        }

        DonorPaymentService.createExceptionPayment(exceptionRequests);
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