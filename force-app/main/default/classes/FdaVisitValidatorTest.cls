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
    static void testTwoDayValidationErrorWithExisting() {
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

        List<Visit__c> testVisits = new List<Visit__c> {
            new Visit__c(
                Appointment__c = testAppointments[0].Id,
                Donor__c = testDonor.PersonContactId,
                Center_Donation_Type__c = testCenterDonationType.Id,
                Status__c = 'Scheduled'
            )
        };
        insert testVisits;

        List<FdaVisitValidator.FdaValidationRequest> fdaValidationRequests = new List<FdaVisitValidator.FdaValidationRequest>{
            new FdaVisitValidator.FdaValidationRequest(testAppointments[1].Id, testDonor.PersonContactId, testCenterDonationType.Id)
        };

        Test.startTest();
        FdaVisitValidator fdaValidatorInstance = new FdaVisitValidator(fdaValidationRequests, false);
        fdaValidationRequests = fdaValidatorInstance.validateCreateVisitRequests();
        Test.stopTest();

        Assert.areEqual(1, fdaValidationRequests.size(), 'All requests should have been returned');

        // The first request should fail since a conflicting visit already exist
        Assert.isNotNull(fdaValidationRequests[0].validationResult, 'A validation result should have been returned');
        Assert.isFalse(fdaValidationRequests[0].validationResult.isValid, 'The validation result should have been invalid');
        Assert.areEqual(expectedErrorMessage, fdaValidationRequests[0].validationResult.errorMessage, 'An error stating the 2 day validation should have been returned');
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

        // The first and second requests should succeed since no visits already exist
        Assert.isNull(fdaValidationRequests[0].validationResult, 'No validation result should have been returned');
        Assert.isNull(fdaValidationRequests[1].validationResult, 'No validation result should have been returned');

        // Only the third request should have failed
        Assert.isNotNull(fdaValidationRequests[2].validationResult, 'A validation result should have been returned');
        Assert.isFalse(fdaValidationRequests[2].validationResult.isValid, 'The validation result should have been invalid');
        Assert.areEqual(expectedErrorMessage, fdaValidationRequests[2].validationResult.errorMessage, 'An error stating the 7 day validation should have been returned');
    }

    @IsTest 
    static void testSevenDayValidationErrorWithExisting() {
        Datetime testDate1 = Datetime.newInstanceGmt(2020, 1, 1, 0, 0, 0);
        Datetime testDate2 = Datetime.newInstanceGmt(2020, 1, 3, 0, 0, 0);
        Datetime testDate3 = Datetime.newInstanceGmt(2020, 1, 6, 0, 0, 0);

        List<String> dateTimeFormattedStrings = new List<String> { testDate1.format('MM-dd-yyyy'), testDate3.format('MM-dd-yyyy') };
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

        List<Visit__c> testVisits = new List<Visit__c> {
            new Visit__c(
                Center_Donation_Type__c = testCenterDonationType.Id,
                Donor__c = testDonor.PersonContactId,
                Appointment__c = testAppointments[0].Id,
                Status__c = 'Scheduled'
            ),
            new Visit__c(
                Center_Donation_Type__c = testCenterDonationType.Id,
                Donor__c = testDonor.PersonContactId,
                Appointment__c = testAppointments[2].Id,
                Status__c = 'Scheduled'
            )
        };
        insert testVisits;

        List<FdaVisitValidator.FdaValidationRequest> fdaValidationRequests = new List<FdaVisitValidator.FdaValidationRequest>{
            new FdaVisitValidator.FdaValidationRequest(testAppointments[1].Id, testDonor.PersonContactId, testCenterDonationType.Id)
        };

        Test.startTest();
        FdaVisitValidator fdaValidatorInstance = new FdaVisitValidator(fdaValidationRequests, false);
        fdaValidationRequests = fdaValidatorInstance.validateCreateVisitRequests();
        Test.stopTest();

        Assert.areEqual(1, fdaValidationRequests.size(), 'All requests should have been returned');

        // The first request should failed because of the existing visits
        Assert.isNotNull(fdaValidationRequests[0].validationResult, 'A validation result should have been returned');
        Assert.isFalse(fdaValidationRequests[0].validationResult.isValid, 'The validation result should have been invalid');
        Assert.areEqual(expectedErrorMessage, fdaValidationRequests[0].validationResult.errorMessage, 'An error stating the 7 day validation should have been returned');
    }

    @IsTest 
    static void testMultiWeekValidationRequest() {
        // Test validation requests across multiple weeks/months to ensure the logic is only checking 7 day violations within the same week
        // All Requests should pass
        List<DateTime> testDatetimes = new List<DateTime> {
            Datetime.newInstanceGmt(2020, 1, 1, 0, 0, 0),
            Datetime.newInstanceGmt(2020, 1, 4, 0, 0, 0),
            Datetime.newInstanceGmt(2020, 1, 8, 0, 0, 0),
            Datetime.newInstanceGmt(2020, 1, 11, 0, 0, 0),
            Datetime.newInstanceGmt(2020, 1, 22, 0, 0, 0),
            Datetime.newInstanceGmt(2020, 2, 3, 0, 0, 0),
            Datetime.newInstanceGmt(2020, 2, 5, 0, 0, 0),
            Datetime.newInstanceGmt(2020, 2, 10, 0, 0, 0),
            Datetime.newInstanceGmt(2020, 3, 10, 0, 0, 0),
            Datetime.newInstanceGmt(2020, 3, 11, 0, 0, 0), // Should fail to 2 day violation (Index 10)
            Datetime.newInstanceGmt(2020, 5, 10, 0, 0, 0),
            Datetime.newInstanceGmt(2020, 5, 15, 0, 0, 0),
            Datetime.newInstanceGmt(2020, 5, 18, 0, 0, 0),
            Datetime.newInstanceGmt(2020, 5, 20, 0, 0, 0)  // Should fail to 7 day violation (Index 14)
        };

        Map<Integer, String> expectedErrorMessages = new Map<Integer, String> {
            9 => 'Donor has more than 1 visit in a 2 day period (Conflicting visits: 03-09-2020)',
            13 => 'Donor has more than 2 visits in a 7 day period (Conflicting visits: 05-14-2020, 05-17-2020)'
        }; 

        Center_Donation_Type__c testCenterDonationType = [SELECT Id, Center__c FROM Center_Donation_Type__c LIMIT 1];
        Schedule__c testSchedule = [SELECT Id FROM Schedule__c WHERE Center__c = :testCenterDonationType.Center__c LIMIT 1];
        Account testDonor = [SELECT Id, PersonContactId FROM Account WHERE DonorId__c != null LIMIT 1];

        List<Appointment__c> testAppointments = new List<Appointment__c>();
        for(DateTime testDatetime : testDatetimes) {
            testAppointments.add(new Appointment__c(
                Schedule__c = testSchedule.Id,
                Capacity__c = 5,
                Datetime__c = testDatetime
            ));
        }
        insert testAppointments;

        List<FdaVisitValidator.FdaValidationRequest> fdaValidationRequests = new List<FdaVisitValidator.FdaValidationRequest>();
        for(Appointment__c testAppointment : testAppointments) {
            fdaValidationRequests.add(new FdaVisitValidator.FdaValidationRequest(testAppointment.Id, testDonor.PersonContactId, testCenterDonationType.Id));
        }

        Test.startTest();
        FdaVisitValidator fdaValidatorInstance = new FdaVisitValidator(fdaValidationRequests, false);
        fdaValidationRequests = fdaValidatorInstance.validateCreateVisitRequests();
        Test.stopTest();

        Assert.areEqual(testDatetimes.size(), fdaValidationRequests.size(), 'All requests should have been returned');

        Integer requestIndex = 0;
        for(FdaVisitValidator.FdaValidationRequest fdaValidationRequest : fdaValidationRequests) {
            String expectedErrorMessage = expectedErrorMessages.get(requestIndex);

            if(expectedErrorMessage != null) {
                Assert.isNotNull(fdaValidationRequest.validationResult, 'A validation result should have been returned');
                Assert.isFalse(fdaValidationRequest.validationResult.isValid, 'The validation result should have been invalid');
                Assert.areEqual(expectedErrorMessage, fdaValidationRequest.validationResult.errorMessage, 'The mapped error message is returned');
            } else {
                Assert.isNull(fdaValidationRequest.validationResult, 'No validation result should have been returned');
            }
            
            requestIndex++;
        }
    }
}