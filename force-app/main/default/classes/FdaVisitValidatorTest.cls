@IsTest
public class FdaVisitValidatorTest {
    @TestSetup
    static void createTestData() {
        Account dallasCenterAccount = TestUtil.createDallasCenter();
        insert dallasCenterAccount;
        
        Center_Donation_Type__c dallasCenterDonationType = TestUtil.createCenterDonationType(dallasCenterAccount.Id);
        insert dallasCenterDonationType;

        List<Account> testDonors = new List<Account>();
        for(Integer i = 0; i < 200; i++) {
            testDonors.add(TestUtil.createDonor(String.valueOf(i).leftPad(6, '0')));
        }

        insert testDonors;

        Datetime testDateTime = Datetime.newInstanceGmt(2020, 1, 1, 0, 0, 0);
        Schedule__c testSchedule = TestUtil.createTestSchedule(dallasCenterAccount.Id, testDateTime);
        insert testSchedule;

        List<Appointment__c> testAppointments = new List<Appointment__c>();
        for(Integer i = 0; i < 600; i++) {
            testAppointments.add(TestUtil.createTestAppointment(testSchedule.Id, testDateTime));
            testDateTime = testDateTime.addHours(1);
        }
        insert testAppointments;
    }

    @IsTest 
    static void testSuccessfulIndividualVisitValidation() {
        Center_Donation_Type__c testCenterDonationType = [SELECT Id, Center__c FROM Center_Donation_Type__c LIMIT 1];

        List<Account> testDonors = [SELECT Id, PersonContactId FROM Account WHERE DonorId__c != null LIMIT 1];
        List<Appointment__c> testAppointments = [SELECT Id FROM Appointment__c WHERE Schedule__r.Center__c = :testCenterDonationType.Center__c];

        List<FdaVisitValidator.FdaValidationRequest> fdaValidationRequests = new List<FdaVisitValidator.FdaValidationRequest>();
        Boolean dontCompareNewVisits = true; // This bool allows us to compare a list of requests against only the existing visits, not the new ones
        Integer initialRequestCount = testAppointments.size();

        for(Appointment__c testAppointment : testAppointments) {
            fdaValidationRequests.add(new FdaVisitValidator.FdaValidationRequest(testAppointment.Id, testDonors[0].PersonContactId, testCenterDonationType.Id));
        }

        Test.startTest();
        FdaVisitValidator fdaValidatorInstance = new FdaVisitValidator(fdaValidationRequests, dontCompareNewVisits);
        fdaValidationRequests = fdaValidatorInstance.validateCreateVisitRequests();
        Test.stopTest();

        Assert.areEqual(initialRequestCount, fdaValidationRequests.size(), 'All requests should have been returned');

        // No Visits currently exist in the system, so we shouldn't get back any errors
        for(FdaVisitValidator.FdaValidationRequest fdaValidationRequest : fdaValidationRequests) {
            Assert.isNull(fdaValidationRequest.validationResult, 'No validation result should have been returned');
        }
    }

    @IsTest
    static void testSuccessfulBulkVisitValidation() {
        Center_Donation_Type__c testCenterDonationType = [SELECT Id, Center__c FROM Center_Donation_Type__c LIMIT 1];

        List<Account> testDonors = [SELECT Id, PersonContactId FROM Account WHERE DonorId__c != null];
        List<Appointment__c> testAppointments = [SELECT Id FROM Appointment__c WHERE Schedule__r.Center__c = :testCenterDonationType.Center__c LIMIT 1];

        List<FdaVisitValidator.FdaValidationRequest> fdaValidationRequests = new List<FdaVisitValidator.FdaValidationRequest>();
        Boolean dontCompareNewVisits = false; // Disabling this means all visits will be compared against each other, not just the existing ones
        Integer initialRequestCount = testDonors.size();

        for(Account testDonor : testDonors) {
            fdaValidationRequests.add(new FdaVisitValidator.FdaValidationRequest(testAppointments[0].Id, testDonor.PersonContactId, testCenterDonationType.Id));
        }

        Test.startTest();
        FdaVisitValidator fdaValidatorInstance = new FdaVisitValidator(fdaValidationRequests, dontCompareNewVisits);
        fdaValidationRequests = fdaValidatorInstance.validateCreateVisitRequests();
        Test.stopTest();

        Assert.areEqual(initialRequestCount, fdaValidationRequests.size(), 'All requests should have been returned');

        // No Visits currently exist in the system, so we shouldn't get back any errors
        for(FdaVisitValidator.FdaValidationRequest fdaValidationRequest : fdaValidationRequests) {
            Assert.isNull(fdaValidationRequest.validationResult, 'No validation result should have been returned');
        }
    }

    @IsTest 
    static void testTwoDayValidationError() {
        Datetime testDate1 = Datetime.newInstanceGmt(2020, 1, 1, 0, 0, 0);
        Datetime testDate2 = Datetime.newInstanceGmt(2020, 1, 2, 0, 0, 0);

        List<String> dateTimeFormattedStrings = new List<String> { testDate1.format('MM-dd-yyyy') };
        String expectedErrorMessage = 'Donor has more than 1 visit in a 2 day period (Conflicting visits: ' + String.join(dateTimeFormattedStrings, ', ') + ')';

        Center_Donation_Type__c testCenterDonationType = [SELECT Id, Center__c FROM Center_Donation_Type__c LIMIT 1];
        Schedule__c testSchedule = [SELECT Id FROM Schedule__c WHERE Center__c = :testCenterDonationType.Center__c LIMIT 1];
        Account testDonor = [SELECT Id, PersonContactId FROM Account WHERE DonorId__c != null LIMIT 1];

        List<Appointment__c> testAppointments = new List<Appointment__c> {
            new Appointment__c(
                Schedule__c = testSchedule.Id,
                Capacity__c = 5,
                Datetime__c = testDate1
            ),
            new Appointment__c(
                Schedule__c = testSchedule.Id,
                Capacity__c = 5,
                Datetime__c = testDate2
            )
        };
        insert testAppointments;

        List<FdaVisitValidator.FdaValidationRequest> fdaValidationRequests = new List<FdaVisitValidator.FdaValidationRequest>{
            new FdaVisitValidator.FdaValidationRequest(testAppointments[0].Id, testDonor.PersonContactId, testCenterDonationType.Id),
            new FdaVisitValidator.FdaValidationRequest(testAppointments[1].Id, testDonor.PersonContactId, testCenterDonationType.Id)
        };

        Test.startTest();
        FdaVisitValidator fdaValidatorInstance = new FdaVisitValidator(fdaValidationRequests, false);
        fdaValidationRequests = fdaValidatorInstance.validateCreateVisitRequests();
        Test.stopTest();

        Assert.areEqual(2, fdaValidationRequests.size(), 'All requests should have been returned');

        // The first request should succeed since no visits already exist
        Assert.isNull(fdaValidationRequests[0].validationResult, 'No validation result should have been returned');

        // Only the second request should have failed
        Assert.isNotNull(fdaValidationRequests[1].validationResult, 'A validation result should have been returned');
        Assert.isFalse(fdaValidationRequests[1].validationResult.isValid, 'The validation result should have been invalid');
        Assert.areEqual(expectedErrorMessage, fdaValidationRequests[1].validationResult.errorMessage, 'An error stating the 2 day validation should have been returned');
    }

    @IsTest
    static void testSevenDayValidationError() {
        Datetime testDate1 = Datetime.newInstanceGmt(2020, 1, 1, 0, 0, 0);
        Datetime testDate2 = Datetime.newInstanceGmt(2020, 1, 3, 0, 0, 0);
        Datetime testDate3 = Datetime.newInstanceGmt(2020, 1, 6, 0, 0, 0);

        List<String> dateTimeFormattedStrings = new List<String> { testDate1.format('MM-dd-yyyy'), testDate2.format('MM-dd-yyyy') };
        String expectedErrorMessage = 'Donor has more than 2 visits in a 7 day period (Conflicting visits: ' + String.join(dateTimeFormattedStrings, ', ') + ')';

        Center_Donation_Type__c testCenterDonationType = [SELECT Id, Center__c FROM Center_Donation_Type__c LIMIT 1];
        Schedule__c testSchedule = [SELECT Id FROM Schedule__c WHERE Center__c = :testCenterDonationType.Center__c LIMIT 1];
        Account testDonor = [SELECT Id, PersonContactId FROM Account WHERE DonorId__c != null LIMIT 1];

        List<Appointment__c> testAppointments = new List<Appointment__c> {
            new Appointment__c(
                Schedule__c = testSchedule.Id,
                Capacity__c = 5,
                Datetime__c = testDate1
            ),
            new Appointment__c(
                Schedule__c = testSchedule.Id,
                Capacity__c = 5,
                Datetime__c = testDate2
            ),
            new Appointment__c(
                Schedule__c = testSchedule.Id,
                Capacity__c = 5,
                Datetime__c = testDate3
            )
        };
        insert testAppointments;

        List<FdaVisitValidator.FdaValidationRequest> fdaValidationRequests = new List<FdaVisitValidator.FdaValidationRequest>{
            new FdaVisitValidator.FdaValidationRequest(testAppointments[0].Id, testDonor.PersonContactId, testCenterDonationType.Id),
            new FdaVisitValidator.FdaValidationRequest(testAppointments[1].Id, testDonor.PersonContactId, testCenterDonationType.Id),
            new FdaVisitValidator.FdaValidationRequest(testAppointments[2].Id, testDonor.PersonContactId, testCenterDonationType.Id)
        };

        Test.startTest();
        FdaVisitValidator fdaValidatorInstance = new FdaVisitValidator(fdaValidationRequests, false);
        fdaValidationRequests = fdaValidatorInstance.validateCreateVisitRequests();
        Test.stopTest();

        Assert.areEqual(3, fdaValidationRequests.size(), 'All requests should have been returned');

        // Only the third request should have failed
        for(FdaVisitValidator.FdaValidationRequest fdaValidationRequest : fdaValidationRequests) {
            Assert.isNotNull(fdaValidationRequest.validationResult, 'A validation result should have been returned');
            Assert.isFalse(fdaValidationRequest.validationResult.isValid, 'The validation result should have been invalid');
            Assert.areEqual(expectedErrorMessage, fdaValidationRequest.validationResult.errorMessage, 'An error stating the 7 day validation should have been returned');
        }
    }
}