public without sharing class PromotionPaymentInvocable {

    @InvocableMethod(Label='Promotion Payment' Category='Payment' Description='Calls Promotion Payment in Donor Payment Service.')
    public static List<PromotionPaymentResponse> invoke(List<PromotionPaymentRequest> promotionPaymentRequests) {
        List<DonorPaymentService.PromotionPaymentRequest> promotionPaymentDonorServiceRequests = new List<DonorPaymentService.PromotionPaymentRequest>();

        for (PromotionPaymentRequest promotionPaymentRequest : promotionPaymentRequests) {
            promotionPaymentDonorServiceRequests.add(new DonorPaymentService.PromotionPaymentRequest(
                promotionPaymentRequest.donorId,
                promotionPaymentRequest.visitId,
                promotionPaymentRequest.amount,
                promotionPaymentRequest.reason
            ));
        }

        List<DonorPaymentService.PromotionPaymentResponse> promotionPaymentDonorServiceResponses = DonorPaymentService.createPromotionPayment(promotionPaymentDonorServiceRequests);
        List<PromotionPaymentResponse> promotionPaymentResponses = new List<PromotionPaymentResponse>();

        for (DonorPaymentService.PromotionPaymentResponse promotionPaymentDonorServiceResponse : promotionPaymentDonorServiceResponses) {
            PromotionPaymentResponse newResponse = new PromotionPaymentResponse();

            newResponse.donorId = promotionPaymentDonorServiceResponse.donorId;
            newResponse.visitId = promotionPaymentDonorServiceResponse.visitId;
            newResponse.amount = promotionPaymentDonorServiceResponse.amount;
            newResponse.reason = promotionPaymentDonorServiceResponse.reason;
            newResponse.transactionId = promotionPaymentDonorServiceResponse.promotionTransactionId;
            
            promotionPaymentResponses.add(newResponse);
        }

        return promotionPaymentResponses;
    }

    public class PromotionPaymentRequest {
        @InvocableVariable
        public Id donorId;

        @InvocableVariable
        public Id visitId;

        @InvocableVariable
        public Decimal amount;

        @InvocableVariable
        public String reason;
    }

    public class PromotionPaymentResponse {
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