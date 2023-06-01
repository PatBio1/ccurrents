public without sharing class PromotionPaymentInvocable {

    @InvocableMethod(Label='Promotion Payment' Category='Payment' Description='Calls Promotion Payment in Donor Payment Service.')
    public static List<PromotionPaymentResponse> invoke(List<PromotionPaymentRequest> promotionPaymentRequests) {
        List<PromotionPaymentResponse> promotionPaymentResponses = new List<PromotionPaymentResponse>();
        List<DonorPaymentService.PromotionPaymentRequest> promotionPaymentDonorServiceRequests = new List<DonorPaymentService.PromotionPaymentRequest>();

        for (PromotionPaymentRequest promotionPaymentRequest : promotionPaymentRequests) {
            promotionPaymentDonorServiceRequests.add(new DonorPaymentService.PromotionPaymentRequest(
                promotionPaymentRequest.donorId,
                promotionPaymentRequest.visitId,
                promotionPaymentRequest.amount,
                promotionPaymentRequest.reason
            ));

            PromotionPaymentResponse promotionPaymentResponse = new PromotionPaymentResponse();
            promotionPaymentResponse.donorId = promotionPaymentRequest.donorId;
            promotionPaymentResponse.visitId = promotionPaymentRequest.visitId;
            promotionPaymentResponse.amount = promotionPaymentRequest.amount;
            promotionPaymentResponse.reason = promotionPaymentRequest.reason;
            promotionPaymentResponses.add(promotionPaymentResponse);
        }

        DonorPaymentService.createPromotionPayment(promotionPaymentDonorServiceRequests);
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