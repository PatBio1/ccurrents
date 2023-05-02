public with sharing class DonationPaymentInvocable {

    @InvocableMethod(Label='Donation Payment' Category='Payment' Description='Calls Donation Payment in Donor Payment Service.')
    public static List<DonationPaymentResponse> invoke(List<DonationPaymentRequest> donationPaymentRequests) {
        List<DonationPaymentResponse> donationPaymentResponses = new List<DonationPaymentResponse>();

        for (DonationPaymentRequest donationPaymentRequest : donationPaymentRequests) {
            DonorPaymentService.createDonationPayment(donationPaymentRequest.donorId, donationPaymentRequest.visitId);

            DonationPaymentResponse donationPaymentResponse = new DonationPaymentResponse();
            donationPaymentResponse.donorId = donationPaymentRequest.donorId;
            donationPaymentResponse.visitId = donationPaymentRequest.visitId;
            donationPaymentResponses.add(donationPaymentResponse);
        }

        return donationPaymentResponses;
    }

    public class DonationPaymentRequest {

        @InvocableVariable
        public Id donorId;

        @InvocableVariable
        public Id visitId;

    }

    public class DonationPaymentResponse {

        @InvocableVariable
        public Id donorId;

        @InvocableVariable
        public Id visitId;

        @InvocableVariable
        public Id transactionId;

    }

}