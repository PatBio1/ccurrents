@RestResource(urlMapping='/v1/Donor')
global without sharing class DonorService {
 
    @HttpPatch
    global static DonorUpdateResponse updateDonor() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;
		String responseBody = request.requestBody.toString();
		DonorUpdate updateRequest = (DonorUpdate)JSON.deserialize(responseBody, DonorUpdate.class);

		DonorUpdateResponse donorUpdateResponse = new DonorUpdateResponse();

		if(String.isBlank(updateRequest.donor_number)){
			donorUpdateResponse.status = 'error';
			donorUpdateResponse.message = 'A donor_id was not provided for BECS/NL enroll_code: '  + updateRequest.enroll_code;
			if(!Test.isRunningTest()){
				RestContext.response.statusCode = 400;
			}
			return donorUpdateResponse;
		}

		Account donorAccount = new Account(
			First_Visit_Code__c = updateRequest.enroll_code,
			DonorId__c = updateRequest.donor_number
		);
		try{
			upsert donorAccount First_Visit_Code__c;
			donorUpdateResponse.status = 'success';
			donorUpdateResponse.message = donorAccount.DonorId__c;
			if(!Test.isRunningTest()){
				RestContext.response.statusCode = 200;
			}
		}catch(DMLException dex){
			if(!Test.isRunningTest()){
				RestContext.response.statusCode = 400;
			}
			donorUpdateResponse.status = 'error';
			donorUpdateResponse.message = 'A Donor could not be found with the BECS/NL enroll_code: ' + updateRequest.enroll_code; 
		}catch (Exception e){
			if(!Test.isRunningTest()){
				RestContext.response.statusCode = 400;
			}
			donorUpdateResponse.status = 'error';
			donorUpdateResponse.message = e.getMessage();
		}
        return donorUpdateResponse;

    }

    global class DonorUpdate{
        global String donor_number {get;set;}
		global String enroll_code {get;set;}
		global DonorUpdate(){}
    }

	global class DonorUpdateResponse{
        global String status {get;set;}
		global String message {get;set;}
		global DonorUpdateResponse(){}
    }
}
