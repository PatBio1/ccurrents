@IsTest
public with sharing class DonorSelectorTest {
    static final String SEARCH_TERM = 'FoundDonor';
    static final Integer EXPECTED_SEARCH_RESULT_COUNT = 3;
    static final Integer EXPECTED_MISSING_SEARCH_RESULT_COUNT = 3;
    
    @TestSetup
    static void createTestData() {
        System.runAs(TestUtil.createAdminUser()) {
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

            Level__c testLevel2 = new Level__c(
                Name = 'Level 2',
                Description__c = 'This is test level 2',
                Donation_Threshold__c = 20
            );
            insert testLevel2;

            Level__c testLevel1 = new Level__c(
                Name = 'Level 1',
                Description__c = 'This is test level 1',
                Donation_Threshold__c = 10,
                Next_Level__c = testLevel2.Id
            );
            insert testLevel1;

            Account donorWithRewards = new Account(
                RecordTypeId = targetDonorRecordTypeId,
                FirstName = 'Donor',
                LastName = 'WithRewards',
                Loyalty_Level__pc = testLevel1.Id,
                Total_Visits_365d__pc = 12
            );
            insert donorWithRewards;

            Id testRewardDonorContactId = [SELECT PersonContactId FROM Account WHERE Id = :donorWithRewards.Id LIMIT 1]?.PersonContactId;
            Visit__c testRewardVisit = new Visit__c(
                Donor__c = testRewardDonorContactId,
                Center_Donation_Type__c = centerDonationType1.Id,
                Status__c = 'Complete',
                Outcome__c = 'Donation'
            );
            insert testRewardVisit;
            
            Transaction__c testRewardTransaction = new Transaction__c(
                Donor__c = testRewardDonorContactId,
                Amount_Points__c = 1000,
                Amount_Currency__c = 10,
                Visit__c = testRewardVisit.Id
            );
            insert testRewardTransaction;

            Proesis_Wallet__c newWalletSettings = new Proesis_Wallet__c(
                Minimum_Withdrawal__c = 2000,
                Points_to_Dollar__c = 100
            );
            insert newWalletSettings;
        }
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
        Assert.areEqual(0, Limits.getQueries(), 'If nothing is passed, no queries should be executed');
        Test.stopTest();

        Assert.areEqual(null, foundDonors, 'If nothing is passed, nothing is returned');
    }

    @IsTest
    static void getDonorRewardsInfoTest() {
        DonorSelector.DonorRewardsInfo donorRewardsInfo;
        User testExperienceUser = TestUtil.createExperienceUserFromContactId([SELECT Id FROM Contact WHERE LastName = 'WithRewards' LIMIT 1].Id);

        Test.startTest();
        System.runAs(testExperienceUser) {
            donorRewardsInfo = DonorSelector.getDonorRewardsInfo();
        }
        Test.stopTest();

        Assert.isNotNull(donorRewardsInfo, 'Expected to find donor rewards info');
        Assert.areEqual(10, donorRewardsInfo.donorBalance, 'Expected to find donor balance of $10');
        Assert.areEqual(1000, donorRewardsInfo.donorPoints, 'Expected to find donor points worth 1000P');
        Assert.areEqual('Level 1', donorRewardsInfo.currentLoyaltyLevel, 'Expected to find donor current level as Level 1');
        Assert.areEqual('Level 2', donorRewardsInfo.nextLoyaltyLevel, 'Expected to find donor next level as Level 2');
        Assert.areEqual(8, donorRewardsInfo.remainingVisitsForNextTier, 'Expected to find donor visits needed for next level as 8');
        Assert.areEqual(2000, donorRewardsInfo.minimumWithdrawalAmount, 'Expected to find minimum equal to org default (2000)');
    }
}