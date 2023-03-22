@isTest
public with sharing class DonorServiceTest {

    @TestSetup
    static void makeData(){
        insert new Account(
            FirstName = 'Danny',
            LastName = 'Donor',
            RecordTypeID = Constants.DONOR_RECORD_TYPE_ID,
            First_Visit_Code__c = 'XXX-123',
            DonorId__c = '1111111',
            PersonOtherPhone = '4153263913'
        );
    }

    @isTest static void testEnrollDonor() {
        RestRequest request = new RestRequest();
        request.requestUri = system.URL.getSalesforceBaseUrl() + '/services/apexrest/Donor';
        System.debug('ReqURI: ' + request.requestUri);
        request.httpMethod = 'PATCH';
        request.addHeader('Content-Type', 'application/json');
        DonorService.DonorEnroll enrollRequest = new DonorService.DonorEnroll();
        enrollRequest.enroll_code = 'XXX-123';
        enrollRequest.donor_number = '8675309';
        request.requestBody = Blob.valueOf(JSON.serialize(enrollRequest));
        RestContext.request = request;
        // Update status of existing record to Working
        DonorService.DonorUpdateResponse donorUpdateResponse;
        Test.startTest();
        System.runAs(TestUtil.createAdminUser()) {
            donorUpdateResponse = DonorService.enrollDonor();
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

    @isTest static void testEnrollDonorError() {
        RestRequest request = new RestRequest();
        request.requestUri = system.URL.getSalesforceBaseUrl() + '/services/apexrest/Donor/';
        System.debug('ReqURI: ' + request.requestUri);
        request.httpMethod = 'PATCH';
        request.addHeader('Content-Type', 'application/json');
        DonorService.DonorEnroll enrollRequest = new DonorService.DonorEnroll();
        enrollRequest.enroll_code = 'XXX-555'; //no match!
        enrollRequest.donor_number = '8675309';
        request.requestBody = Blob.valueOf(JSON.serialize(enrollRequest));
        RestContext.request = request;
        // Update status of existing record to Working
        DonorService.DonorUpdateResponse donorUpdateResponse;
        Test.startTest();
        System.runAs(TestUtil.createAdminUser()) {
            donorUpdateResponse = DonorService.enrollDonor();
        }
        Test.stopTest();
        System.debug('Response: ' + donorUpdateResponse);
        // Verify record was updated
        System.assertEquals('error',donorUpdateResponse.status );
        System.assertEquals('A Donor could not be found with the BECS/NL enroll_code: XXX-555',donorUpdateResponse.message );

    }

    @isTest static void testEnrollDonorError2() {
        RestRequest request = new RestRequest();
        request.requestUri = system.URL.getSalesforceBaseUrl() + '/services/apexrest/Donor/';
        System.debug('ReqURI: ' + request.requestUri);
        request.httpMethod = 'PATCH';
        request.addHeader('Content-Type', 'application/json');
        DonorService.DonorEnroll enrollRequest = new DonorService.DonorEnroll();
        enrollRequest.enroll_code = 'XXX-555'; //no match!
        // enrollRequest.donor_number = '8675309';
        request.requestBody = Blob.valueOf(JSON.serialize(enrollRequest));
        RestContext.request = request;
        // Update status of existing record to Working
        DonorService.DonorUpdateResponse donorUpdateResponse;
        Test.startTest();
        System.runAs(TestUtil.createAdminUser()) {
            donorUpdateResponse = DonorService.enrollDonor();
        }
        Test.stopTest();
        System.debug('Response: ' + donorUpdateResponse);
        // Verify record was updated
        System.assertEquals('error',donorUpdateResponse.status );
        System.assertEquals('A donor_id was not provided for BECS/NL enroll_code: XXX-555',donorUpdateResponse.message );

    }

    @isTest static void testUpdateDonor() {
        RestRequest request = new RestRequest();
        request.requestUri = system.URL.getSalesforceBaseUrl() + '/services/apexrest/Donor/';
        System.debug('ReqURI: ' + request.requestUri);
        request.httpMethod = 'PUT';
        request.addHeader('Content-Type', 'application/json');
        DonorService.DonorUpdate updateRequest = new DonorService.DonorUpdate();
        updateRequest.donor_number = '1111111';
        updateRequest.birthdate = '2000-10-20';
        updateRequest.last_name = 'Bondo';
        updateRequest.first_name = 'Bette';
        updateRequest.middle_name = 'D';
        updateRequest.address_line1 = '123 Ordinary Dr';
        updateRequest.address_line2 = 'Apt B';
        updateRequest.primary_phone = '4235804176';
        updateRequest.secondary_phone = ''; //should null out any existing value
        updateRequest.city = 'Chattanooga';
        updateRequest.state = 'TN';
        updateRequest.zipcode = '37350';
        updateRequest.height = '72';
        updateRequest.weight = '185';
        updateRequest.ethnicity = 'White';
        updateRequest.timestamp = '2022-11-29T08:40:00.000Z';

        request.requestBody = Blob.valueOf(JSON.serialize(updateRequest));
        RestContext.request = request;


        DonorService.DonorUpdateResponse donorUpdateResponse;
        Test.startTest();
        System.runAs(TestUtil.createAdminUser()) {
            donorUpdateResponse = DonorService.updateDonor();
        }
        Test.stopTest();
        system.assertEquals('success',donorUpdateResponse.status);
        system.assertEquals('1111111',donorUpdateResponse.message);
        Account donorAccount = [
            SELECT  Id,
                    PersonBirthdate,
                    LastName,
                    FirstName,
                    MiddleName,
                    PersonMailingStreet,
                    Phone,
                    PersonOtherPhone,
                    PersonMailingCity,
                    PersonMailingState,
                    PersonMailingPostalCode,
                    Height__pc,
                    Weight__pc,
                    Ethnicity__pc
            FROM Account
            WHERE DonorId__c = '1111111'

        ];
        system.assertEquals(Date.newInstance(2000,10,20),donorAccount.PersonBirthdate);
        system.assertEquals(updateRequest.last_name,donorAccount.LastName);
        system.assertEquals(updateRequest.first_name,donorAccount.FirstName);
        system.assertEquals(updateRequest.middle_name,donorAccount.MiddleName);
        system.assertEquals(updateRequest.address_line1 + ', ' + updateRequest.address_line2, donorAccount.PersonMailingStreet);

        system.assertEquals(updateRequest.primary_phone,donorAccount.Phone);
        system.assertEquals(null,donorAccount.PersonOtherPhone);
        system.assertEquals(updateRequest.city,donorAccount.PersonMailingCity);
        system.assertEquals(updateRequest.state,donorAccount.PersonMailingState);
        system.assertEquals(updateRequest.zipcode,donorAccount.PersonMailingPostalCode);
        system.assertEquals(Decimal.valueOf(updateRequest.height),donorAccount.Height__pc);
        system.assertEquals(Decimal.valueOf(updateRequest.weight),donorAccount.Weight__pc);
        system.assertEquals(updateRequest.ethnicity,donorAccount.Ethnicity__pc);

    }

    @isTest static void testUpdateDonorError() {
        RestRequest request = new RestRequest();
        request.requestUri = system.URL.getSalesforceBaseUrl() + '/services/apexrest/Donor/';
        System.debug('ReqURI: ' + request.requestUri);
        request.httpMethod = 'PUT';
        request.addHeader('Content-Type', 'application/json');
        DonorService.DonorUpdate updateRequest = new DonorService.DonorUpdate();

        request.requestBody = Blob.valueOf(JSON.serialize(updateRequest));
        RestContext.request = request;


        DonorService.DonorUpdateResponse donorUpdateResponse;
        Test.startTest();
        System.runAs(TestUtil.createAdminUser()) {
            donorUpdateResponse = DonorService.updateDonor();
        }
        Test.stopTest();
        system.assertEquals('error',donorUpdateResponse.status);
        system.assertEquals('A donor could not be found for BECS/NL donor_number: null',donorUpdateResponse.message);

    }

}