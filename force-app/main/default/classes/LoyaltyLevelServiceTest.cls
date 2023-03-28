@IsTest
public class LoyaltyLevelServiceTest {
    @TestSetup
    static void makeTestData() {
        List<Level__c> testLoyaltyLevels = new List<Level__c>{
            new Level__c(Name = 'Bronze', Donation_Threshold__c = 10, Description__c = 'Bronze description'),
            new Level__c(Name = 'Silver', Donation_Threshold__c = 20, Description__c = 'Silver description'),
            new Level__c(Name = 'Gold', Donation_Threshold__c = 30, Description__c = 'Gold description')
        };
        insert testLoyaltyLevels;
    }

    @IsTest
    static void getLoyaltyLevelDisplayInfoTest() {
        List<LoyaltyLevelService.LoyaltyLevel> foundLoyaltyLevels;

        Test.startTest();
        foundLoyaltyLevels = LoyaltyLevelService.getLoyaltyLevelDisplayInfo();
        Test.stopTest();

        System.assertEquals(3, foundLoyaltyLevels.size(), 'Should have found 3 loyalty levels');

        System.assertEquals('Bronze', foundLoyaltyLevels[0].levelName, 'Should have found Bronze loyalty level');
        System.assertEquals(10, foundLoyaltyLevels[0].levelThreshold, 'Bronze level should have a donation threshold of 10');
        System.assertEquals('Bronze description', foundLoyaltyLevels[0].levelDescription, 'Bronze level should have a description of Bronze description');

        System.assertEquals('Silver', foundLoyaltyLevels[1].levelName, 'Should have found Silver loyalty level');
        System.assertEquals(20, foundLoyaltyLevels[1].levelThreshold, 'Silver level should have a donation threshold of 20');
        System.assertEquals('Silver description', foundLoyaltyLevels[1].levelDescription, 'Silver level should have a description of Silver description');

        System.assertEquals('Gold', foundLoyaltyLevels[2].levelName, 'Should have found Gold loyalty level');
        System.assertEquals(30, foundLoyaltyLevels[2].levelThreshold, 'Gold level should have a donation threshold of 30');
        System.assertEquals('Gold description', foundLoyaltyLevels[2].levelDescription, 'Gold level should have a description of Gold description');
    }
}