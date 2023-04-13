@IsTest
public class LoyaltyLevelServiceTest {
    @TestSetup
    static void makeTestData() {
        List<Level__c> testLoyaltyLevels = new List<Level__c>{
            new Level__c(Name = 'Inactive', Donation_Threshold__c = 5, Description__c = 'Inactive description', isActive__c = false, isVisible__c = false),
            new Level__c(Name = 'Invisible', Donation_Threshold__c = 5, Description__c = 'Invisible description', isActive__c = true, isVisible__c = false),
            new Level__c(Name = 'Bronze', Donation_Threshold__c = 10, Description__c = 'Bronze description', isActive__c = true, isVisible__c = true),
            new Level__c(Name = 'Silver', Donation_Threshold__c = 20, Description__c = 'Silver description', isActive__c = true, isVisible__c = true),
            new Level__c(Name = 'Gold', Donation_Threshold__c = 30, Description__c = 'Gold description', isActive__c = true, isVisible__c = true)
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

    @IsTest 
    static void getLoyaltyBadgeDisplaySettingsTest() {
        List<LoyaltyLevelService.BadgeSetting> foundBadgeSettings;

        Test.startTest();
        foundBadgeSettings = LoyaltyLevelService.getLoyaltyBadgeDisplaySettings();
        Test.stopTest();

        System.assertEquals(3, foundBadgeSettings.size(), 'Should have found 3 badge settings');

        System.assertEquals('Bronze', foundBadgeSettings[0].badgeName, 'Should have found Bronze badge setting');
        System.assertEquals('bronze', foundBadgeSettings[0].badgeFileName, 'Bronze badge setting should have a file name of bronze');

        System.assertEquals('Silver', foundBadgeSettings[1].badgeName, 'Should have found Silver badge setting');
        System.assertEquals('silver', foundBadgeSettings[1].badgeFileName, 'Silver badge setting should have a file name of silver');

        System.assertEquals('Gold', foundBadgeSettings[2].badgeName, 'Should have found Gold badge setting');
        System.assertEquals('gold', foundBadgeSettings[2].badgeFileName, 'Gold badge setting should have a file name of gold');
    }
}