@RestResource(urlMapping='/v1/Donor')
global without sharing class DonorService {
  @HttpPut
  global static donorUpdateResponse updateDonor() {
    RestRequest request = RestContext.request;
    RestResponse response = RestContext.response;
    String responseBody = request.requestBody.toString();
    DonorUpdate donorUpdateRequest = (DonorUpdate) JSON.deserialize(
      responseBody,
      DonorUpdate.class
    );
    // map request fields to Person Account
    DonorUpdateResponse donorUpdateResponse = mapFieldsToAccount(
      donorUpdateRequest
    );

    // donorUpdateResponse.status = 'success';
    // donorUpdateResponse.message = donorUpdateRequest.donor_number;
    if (!Test.isRunningTest() && donorUpdateResponse.status == 'error') {
      RestContext.response.statusCode = 500;
    }
    return donorUpdateResponse;
    // return JSON.serializePretty(donorUpdateRequest);
  }

  public static DonorUpdateResponse mapFieldsToAccount(
    DonorUpdate donorUpdateRequest
  ) {
    Account donorAccount;
    DonorUpdateResponse donorUpdateResponse = new DonorUpdateResponse();
    for (Account acc : [
      SELECT Id, DonorId__c
      FROM Account
      WHERE DonorId__c != NULL AND DonorId__c = :donorUpdateRequest.donor_number
    ]) {
      donorAccount = acc;
    }
    if (donorAccount == null) {
      donorUpdateResponse.status = 'error';
      donorUpdateResponse.message =
        'A donor could not be found for BECS/NL donor_number: ' +
        donorUpdateRequest.donor_number;
      return donorUpdateResponse;
    } else {
      //if request property is null, then property was not sent in original message
      // if it a blank string (not null), only then do we overwrite field with a null value
      try {
        //birthdate
        if (donorUpdateRequest.birthdate != null) {
          if (String.isBlank(donorUpdateRequest.birthdate)) {
            donorAccount.PersonBirthdate = null;
          } else {
            String[] DateParts = donorUpdateRequest.birthdate.split('-');
            Integer year = Integer.valueOf(DateParts[0]);
            Integer month = Integer.valueOf(DateParts[1]);
            Integer day = Integer.valueOf(DateParts[2]);
            donorAccount.PersonBirthdate = Date.newInstance(year, month, day);
          }
        }
        //last_name
        if (donorUpdateRequest.last_name != null) {
          donorAccount.LastName = nullOrBlank(donorUpdateRequest.last_name);
        }
        //first_name
        if (donorUpdateRequest.first_name != null) {
          donorAccount.FirstName = nullOrBlank(donorUpdateRequest.first_name);
        }
        // middle_name
        if (donorUpdateRequest.middle_name != null) {
          donorAccount.MiddleName = nullOrBlank(donorUpdateRequest.middle_name);
        }
        // address_line1
        if (donorUpdateRequest.address_line1 != null) {
          donorAccount.PersonMailingStreet = nullOrBlank(
            donorUpdateRequest.address_line1
          );
        }
        // address_line2
        if (donorUpdateRequest.address_line2 != null) {
          if (donorAccount.PersonMailingStreet == null) {
            donorAccount.PersonMailingStreet = nullOrBlank(
              donorUpdateRequest.address_line2
            );
          } else {
            donorAccount.PersonMailingStreet +=
              ', ' + nullOrBlank(donorUpdateRequest.address_line2);
          }
        }
        // primary_phone
        if (donorUpdateRequest.primary_phone != null) {
          donorAccount.PersonMobilePhone = nullOrBlank(
            donorUpdateRequest.primary_phone
          );
        }
        // secondary_phone
        if (donorUpdateRequest.secondary_phone != null) {
          donorAccount.PersonOtherPhone = nullOrBlank(
            donorUpdateRequest.secondary_phone
          );
        }
        // city
        if (donorUpdateRequest.city != null) {
          donorAccount.PersonMailingCity = nullOrBlank(donorUpdateRequest.city);
        }
        // state
        if (donorUpdateRequest.state != null) {
          donorAccount.PersonMailingState = nullOrBlank(
            donorUpdateRequest.state
          );
        }
        // zipcode
        if (donorUpdateRequest.zipcode != null) {
          donorAccount.PersonMailingPostalCode = nullOrBlank(
            donorUpdateRequest.zipcode
          );
        }
        // height
        if (donorUpdateRequest.height != null) {
          donorAccount.Height__pc = nullOrBlankNumber(
            donorUpdateRequest.height
          );
        }
        // weight
        if (donorUpdateRequest.weight != null) {
          donorAccount.Weight__pc = nullOrBlankNumber(
            donorUpdateRequest.weight
          );
        }
        // race
        if (donorUpdateRequest.ethnicity != null) {
          donorAccount.Race__pc = nullOrBlank(donorUpdateRequest.ethnicity);
        }
        /*/ ethnicity
				if(donorUpdateRequest.ethnicity != null){
					donorAccount.Ethnicity__pc = nullOrBlank(donorUpdateRequest.ethnicity);
				} */

        donorUpdateResponse.status = 'success';
        donorUpdateResponse.message = donorAccount.DonorId__c;

        update donorAccount;
      } catch (Exception e) {
        donorUpdateResponse.status = 'error';
        donorUpdateResponse.message = e.getMessage();
      }
    }
    return donorUpdateResponse;
  }

  public static string nullOrBlank(String field) {
    if (String.isBlank(field)) {
      return null;
    } else {
      return field;
    }
  }
  public static Decimal nullOrBlankNumber(String field) {
    if (String.isBlank(field)) {
      return null;
    } else {
      return Decimal.valueOf(field);
    }
  }

  @HttpPatch
  global static DonorUpdateResponse enrollDonor() {
    RestRequest request = RestContext.request;
    RestResponse response = RestContext.response;
    String responseBody = request.requestBody.toString();
    DonorEnroll enrollRequest = (DonorEnroll) JSON.deserialize(
      responseBody,
      DonorEnroll.class
    );

    DonorUpdateResponse donorUpdateResponse = new DonorUpdateResponse();

    if (String.isBlank(enrollRequest.donor_number)) {
      donorUpdateResponse.status = 'error';
      donorUpdateResponse.message =
        'A donor_id was not provided for BECS/NL enroll_code: ' +
        enrollRequest.enroll_code;
      if (!Test.isRunningTest()) {
        RestContext.response.statusCode = 400;
      }
      return donorUpdateResponse;
    }

    Account donorAccount = new Account(
      First_Visit_Code__c = enrollRequest.enroll_code,
      DonorId__c = enrollRequest.donor_number
    );
    try {
      upsert donorAccount First_Visit_Code__c;
      donorUpdateResponse.status = 'success';
      donorUpdateResponse.message = donorAccount.DonorId__c;
      if (!Test.isRunningTest()) {
        RestContext.response.statusCode = 200;
      }
    } catch (DMLException dex) {
      if (!Test.isRunningTest()) {
        RestContext.response.statusCode = 400;
      }
      donorUpdateResponse.status = 'error';
      donorUpdateResponse.message =
        'A Donor could not be found with the BECS/NL enroll_code: ' +
        enrollRequest.enroll_code;
    } catch (Exception e) {
      if (!Test.isRunningTest()) {
        RestContext.response.statusCode = 400;
      }
      donorUpdateResponse.status = 'error';
      donorUpdateResponse.message = e.getMessage();
    }
    return donorUpdateResponse;
  }

  global class DonorEnroll {
    global String donor_number { get; set; }
    global String enroll_code { get; set; }
    global DonorEnroll() {
    }
  }

  global class DonorUpdate {
    global String donor_number { get; set; }
    global String birthdate { get; set; }
    global String last_name { get; set; }
    global String first_name { get; set; }
    global String middle_name { get; set; }
    global String address_line1 { get; set; }
    global String address_line2 { get; set; }
    global String primary_phone { get; set; }
    global String secondary_phone { get; set; }
    global String city { get; set; }
    global String state { get; set; }
    global String zipcode { get; set; }
    global String height { get; set; }
    global String weight { get; set; }
    global String ethnicity { get; set; }
    global String language { get; set; }
    global String timestamp { get; set; }
    global DonorUpdate() {
    }
  }

  global class DonorUpdateResponse {
    global String status { get; set; }
    global String message { get; set; }
    global DonorUpdateResponse() {
    }
  }

  public class DonorServiceException extends Exception {
  }
}
