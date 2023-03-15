@IsTest
public with sharing class DonorSelectorTest {
    static final String SEARCH_TERM = 'FoundDonor';
    static final Integer EXPECTED_SEARCH_RESULT_COUNT = 3;
    static final Integer EXPECTED_MISSING_SEARCH_RESULT_COUNT = 3;
    
    @TestSetup
    static void createTestData() {
        String targetDonorRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Donor').getRecordTypeId();
        String targetCenterRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Center').getRecordTypeId();

        List<Account> donorsAndCenter = new List<Account> {
            new Account(
                Name = 'Test Donor Center',
                RecordTypeId = targetCenterRecordTypeId,
                Services__c = 'Donation',
                IsActive__c = true
            )
        };

        for(Integer i = 0; i < EXPECTED_SEARCH_RESULT_COUNT; i++) {
            donorsAndCenter.add(
                new Account(
                    FirstName = SEARCH_TERM + 'Test' + (i + 1),
                    LastName = 'Tester',
                    RecordTypeId = targetDonorRecordTypeId
                )
            );
        }
        for(Integer j = 0; j < EXPECTED_MISSING_SEARCH_RESULT_COUNT; j++) {
            donorsAndCenter.add(
                new Account(
                    FirstName = 'MissingDonor' + 'Test' + (j + 1),
                    LastName = 'Tester',
                    RecordTypeId = targetDonorRecordTypeId
                )
            );
        }

        insert donorsAndCenter;

        Donation_Type__c testDonationType = new Donation_Type__c(
            Name = 'Donation Type 1'
        );
        insert testDonationType;

        Center_Donation_Type__c centerDonationType1 = new Center_Donation_Type__c(
            Center__c = donorsAndCenter[0].Id,
            Donation_Type__c = testDonationType.Id,
            isActive__c = true
        );
        insert centerDonationType1;
    }

    @IsTest
    static void searchVisitElgibleDonorByNameSuccessTest() {
        List<Account> foundDonors;

        Test.startTest();
        foundDonors = DonorSelector.searchVisitElgibleDonorByName(SEARCH_TERM, DateTime.now());
        Test.stopTest();

        Assert.areEqual(EXPECTED_SEARCH_RESULT_COUNT, foundDonors.size(), 'Expected to find ' + EXPECTED_SEARCH_RESULT_COUNT + ' donors.');
    }

    @IsTest
    static void searchVisitElgibleDonorByNameNoResultsTest() {
        List<Account> foundDonors;

        Test.startTest();
        foundDonors = DonorSelector.searchVisitElgibleDonorByName('RandomTermThatHasNoResultsHere', DateTime.now());
        Test.stopTest();

        Assert.areEqual(0, foundDonors.size(), 'Expected No Results when a nonsense string is provided');
    }

    @IsTest
    static void searchVisitElgibleDonorByNameNoSearchTermTest() {
        List<Account> foundDonors;

        Test.startTest();
        foundDonors = DonorSelector.searchVisitElgibleDonorByName(null, DateTime.now());
        Test.stopTest();

        Assert.areEqual(null, foundDonors, 'If nothing is passed, nothing is returned');
        Assert.areEqual(0, Limits.getQueries(), 'If nothing is passed, no queries should be executed');
    }
}