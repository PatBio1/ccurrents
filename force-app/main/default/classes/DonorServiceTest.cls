@isTest
public with sharing class DonorServiceTest {
    @isTest static void testUpdateDonor() {
        RestRequest request = new RestRequest();
        request.requestUri = system.URL.getSalesforceBaseUrl() + '/services/apexrest/Donor/';
        System.debug('ReqURI: ' + request.requestUri);
        request.httpMethod = 'PATCH';
        request.addHeader('Content-Type', 'application/json');
        request.requestBody = Blob.valueOf('{ "donor_number" : "123456", "birthdate" : "2000-10-20", "last_name" : "Davis", "first_name" : "David", "middle_name" : "D", "address_line1" : "123 Ordinary Dr", "address_line2" : "Apt B", "primary_phone" : "4235804176", "secondary_phone" : "", "city" : "Chattanooga", "state" : "TN", "zipcode" : "37350", "height" : "72", "weight" : "185", "ethnicity" : "R5", "language" : "en", "timestamp": "2022-11-29T08:40:00.000Z" }');
        RestContext.request = request;
        // Update status of existing record to Working
        String result = DonorService.echoDonorUpdate();
        System.debug('Response: ' + result);
        // Verify record was updated
        System.assert(result != null);
        System.assert(result.contains('donor_number') == true);

    }  

}