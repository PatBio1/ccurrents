public with sharing class DonationPaymentInvocable {

    @InvocableMethod(Label='Donation Payment' Category='Payment' Description='Calls Donation Payment in Donor Payment Service.')
    public static List<DonationPaymentResponse> invoke(List<DonationPaymentRequest> donationPaymentRequests) {
        List<DonorPaymentService.DonationPaymentRequest> servicePaymentRequests = new List<DonorPaymentService.DonationPaymentRequest>();

        for(DonationPaymentRequest donationPaymentRequest : donationPaymentRequests) {
            DonorPaymentService.DonationPaymentRequest servicePaymentRequest = new DonorPaymentService.DonationPaymentRequest(
                donationPaymentRequest.donorId,
                donationPaymentRequest.visitId
            );

            servicePaymentRequests.add(servicePaymentRequest);
        }

        List<DonorPaymentService.DonationPaymentResponse> servicePaymentResponses = DonorPaymentService.createDonationPayment(servicePaymentRequests);
        List<DonationPaymentResponse> donationPaymentResponses = new List<DonationPaymentResponse>();

        for (DonorPaymentService.DonationPaymentResponse serviceResponse : servicePaymentResponses) {
            DonationPaymentResponse donationPaymentResponse = new DonationPaymentResponse();

            donationPaymentResponse.donorId = serviceResponse.donorId;
            donationPaymentResponse.visitId = serviceResponse.visitId;
            donationPaymentResponse.transactionId = serviceResponse.transactionRecord.Id;

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