@isTest
public with sharing class DonorServiceTest {

    @TestSetup
    static void makeData(){
        insert new Account(
            FirstName = 'Danny',
            LastName = 'Donor',
            RecordTypeID = Constants.DONOR_RECORD_TYPE_ID,
            First_Visit_Code__c = 'XXX-123'
        );
    }

    @isTest static void testUpdateDonor() {
        RestRequest request = new RestRequest();
        request.requestUri = system.URL.getSalesforceBaseUrl() + '/services/apexrest/Donor/';
        System.debug('ReqURI: ' + request.requestUri);
        request.httpMethod = 'PATCH';
        request.addHeader('Content-Type', 'application/json');
        DonorService.DonorUpdate updateRequest = new DonorService.DonorUpdate();
        updateRequest.enroll_code = 'XXX-123';
        updateRequest.donor_number = '8675309';
        request.requestBody = Blob.valueOf(JSON.serialize(updateRequest));
        RestContext.request = request;
        // Update status of existing record to Working
        DonorService.DonorUpdateResponse donorUpdateResponse;
        Test.startTest();
        System.runAs(TestUtil.createAdminUser()) {
            donorUpdateResponse = DonorService.updateDonor();
        }
        Test.stopTest();
        System.debug('Response: ' + donorUpdateResponse);
        // Verify record was updated
        System.assertEquals('success',donorUpdateResponse.status );
        System.assertEquals('8675309',donorUpdateResponse.message );
        Account donorAccount = [
            SELECT Id,First_Visit_Code__c,DonorId__c
            FROM Account WHERE First_Visit_Code__c = 'XXX-123'
        ];
        system.assertEquals('8675309',donorAccount.DonorId__c );

    }

    @isTest static void testUpdateDonorError() {
        RestRequest request = new RestRequest();
        request.requestUri = system.URL.getSalesforceBaseUrl() + '/services/apexrest/Donor/';
        System.debug('ReqURI: ' + request.requestUri);
        request.httpMethod = 'PATCH';
        request.addHeader('Content-Type', 'application/json');
        DonorService.DonorUpdate updateRequest = new DonorService.DonorUpdate();
        updateRequest.enroll_code = 'XXX-555'; //no match!
        updateRequest.donor_number = '8675309';
        request.requestBody = Blob.valueOf(JSON.serialize(updateRequest));
        RestContext.request = request;
        // Update status of existing record to Working
        DonorService.DonorUpdateResponse donorUpdateResponse;
        Test.startTest();
        System.runAs(TestUtil.createAdminUser()) {
            donorUpdateResponse = DonorService.updateDonor();
        }
        Test.stopTest();
        System.debug('Response: ' + donorUpdateResponse);
        // Verify record was updated
        System.assertEquals('error',donorUpdateResponse.status );
        System.assertEquals('A Donor could not be found with the BECS/NL enroll_code: XXX-555',donorUpdateResponse.message );

    }

    @isTest static void testUpdateDonorError2() {
        RestRequest request = new RestRequest();
        request.requestUri = system.URL.getSalesforceBaseUrl() + '/services/apexrest/Donor/';
        System.debug('ReqURI: ' + request.requestUri);
        request.httpMethod = 'PATCH';
        request.addHeader('Content-Type', 'application/json');
        DonorService.DonorUpdate updateRequest = new DonorService.DonorUpdate();
        updateRequest.enroll_code = 'XXX-555'; //no match!
        // updateRequest.donor_number = '8675309';
        request.requestBody = Blob.valueOf(JSON.serialize(updateRequest));
        RestContext.request = request;
        // Update status of existing record to Working
        DonorService.DonorUpdateResponse donorUpdateResponse;
        Test.startTest();
        System.runAs(TestUtil.createAdminUser()) {
            donorUpdateResponse = DonorService.updateDonor();
        }
        Test.stopTest();
        System.debug('Response: ' + donorUpdateResponse);
        // Verify record was updated
        System.assertEquals('error',donorUpdateResponse.status );
        System.assertEquals('A donor_id was not provided for BECS/NL enroll_code: XXX-555',donorUpdateResponse.message );

    }

}