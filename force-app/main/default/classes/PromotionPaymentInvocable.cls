public without sharing class PromotionPaymentInvocable {

    @InvocableMethod(Label='Promotion Payment' Category='Payment' Description='Calls Promotion Payment in Donor Payment Service.')
    public static List<PromotionPaymentResponse> invoke(List<PromotionPaymentRequest> promotionPaymentRequests) {
        List<PromotionPaymentResponse> promotionPaymentResponses = new List<PromotionPaymentResponse>();
        List<PromotionPaymentRequest> promotionPaymentDonorServiceRequests = new List<PromotionPaymentRequest>();

        for (PromotionPaymentRequest promotionPaymentRequest : promotionPaymentRequests) {
            PromotionPaymentRequest promotionRequest = new PromotionPaymentRequest();

            promotionRequest.donorId = promotionPaymentRequest.donorId;
            promotionRequest.visitId = promotionPaymentRequest.visitId;
            promotionRequest.amount = promotionPaymentRequest.amount;
            promotionRequest.reason = promotionPaymentRequest.reason;
            
            promotionPaymentDonorServiceRequests.add(promotionRequest);
        }

        return DonorPaymentService.createPromotionPayment(promotionPaymentDonorServiceRequests);
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