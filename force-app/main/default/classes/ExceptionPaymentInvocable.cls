public with sharing class ExceptionPaymentInvocable {

    @InvocableMethod(Label='Exception Payment' Category='Payment' Description='Calls Exception Payment in Donor Payment Service.')
    public static List<ExceptionPaymentResponse> invoke(List<ExceptionPaymentRequest> exceptionPaymentRequests) {
        List<ExceptionPaymentResponse> exceptionPaymentResponses = new List<ExceptionPaymentResponse>();

        for (ExceptionPaymentRequest exceptionPaymentRequest : exceptionPaymentRequests) {
            DonorPaymentService.createExceptionPayment(exceptionPaymentRequest.donorId, exceptionPaymentRequest.visitId, exceptionPaymentRequest.amount);

            ExceptionPaymentResponse exceptionPaymentResponse = new ExceptionPaymentResponse();
            exceptionPaymentResponse.donorId = exceptionPaymentRequest.donorId;
            exceptionPaymentResponse.visitId = exceptionPaymentRequest.visitId;
            exceptionPaymentResponse.amount = exceptionPaymentRequest.amount;
            exceptionPaymentResponses.add(exceptionPaymentResponse);
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

    }

    public class ExceptionPaymentResponse {

        @InvocableVariable
        public Id donorId;

        @InvocableVariable
        public Id visitId;

        @InvocableVariable
        public Decimal amount;

    }

}