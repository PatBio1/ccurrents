@RestResource(urlMapping='/v1/Donor')
global without sharing class DonorService {
 
    @HttpPatch
    global static String echoDonorUpdate() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;
        return request.requestBody.toString();
      // For the moment we are merely returning the values passed in
      // A future version will check if entroll_id is not null in the call, and 1) if not null it will 
      // be used to find the new donor and update with the payload values using the donor_number 
      // otherwise 2) the donor_number will be used to update the existing Donor as an external_ID from the BECS/Nexlynk system
    }

}
