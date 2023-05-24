@IsTest
public without sharing class RateSelectorTest {
    private static final String TEST_DONATION_TYPE = 'Normal Plasma';
    private static final Integer TEST_BASE_PAYMENT = 50;
    private static final String TEST_UOM = 'visit';

    @TestSetup
    static void createTestData() {
        Account testCenter = TestUtil.createMiramarCenter();
        insert testCenter;

        Donation_Type__c testDonationType = new Donation_Type__c(Name = TEST_DONATION_TYPE);
        insert testDonationType;

        Rate__c testRate = new Rate__c(
            Donation_Type__c = testDonationType.Id,
            Center__c = testCenter.Id,
            Base_Payment__c = TEST_BASE_PAYMENT,
            UOM__c = TEST_UOM,
            Type__c = 'Base'
        );
        insert testRate;

        Level__c defaultLevel = new Level__c(
            Name = 'Default',
            Donation_Threshold__c = 0,
            Donation_Payment__c = TEST_BASE_PAYMENT,
            Donation_Points__c = TEST_BASE_PAYMENT
        );
        insert defaultLevel;
    }

    @IsTest 
    static void testGetCenterRate() {
        Account center = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Center' LIMIT 1];
        Rate__c targetRateRecord = [SELECT Id FROM Rate__c WHERE Center__c = :center.Id LIMIT 1];
        RateSelector.Rate foundRate;

        Test.startTest();
        foundRate = RateSelector.getCenterRate(center.Id, TEST_DONATION_TYPE);
        Test.stopTest();

        Assert.isNotNull(foundRate, 'A rate should have been returned');
        Assert.areEqual(foundRate.basePayment, TEST_BASE_PAYMENT * 2, 'The base payment should have been returned');
        Assert.areEqual(foundRate.basePoints, TEST_BASE_PAYMENT, 'The base points should have been returned');
        Assert.areEqual(foundRate.uom, TEST_UOM, 'The uom should have been returned');
        Assert.areEqual(foundRate.donationType, TEST_DONATION_TYPE, 'The donation type should have been returned');
        Assert.areEqual(foundRate.center, center.Id, 'The center Id should have been returned');
        Assert.areEqual(foundRate.id, targetRateRecord.Id, 'The rate Id should have been returned');
    }
}