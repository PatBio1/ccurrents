public without sharing class LoyaltyLevelService {

    private static Map<Id, Integer> loyaltyLevelIdToIndex;

    public static Level__c getDefault() {
        return [
            SELECT
                Id, Donation_Points__c, Donation_Payment__c
            FROM
                Level__c
            WHERE
                Donation_Threshold__c = 0
            LIMIT
                1
        ];
    }

    public static Integer getLoyaltyLevel(Id loyaltyLevelId) {
        if (loyaltyLevelIdToIndex == null) {
            loyaltyLevelIdToIndex = new Map<Id, Integer>();

            Integer loyaltyLevelIndex = 0;
            for (Level__c loyaltyLevelRecord : [
                SELECT Id
                FROM Level__c
                WHERE isActive__c = true 
                ORDER BY Donation_Threshold__c ASC
            ]) {
                loyaltyLevelIdToIndex.put(loyaltyLevelRecord.Id, loyaltyLevelIndex);
                loyaltyLevelIndex += 1;
            }
        }

        return loyaltyLevelIdToIndex.get(loyaltyLevelId);
    }

    @AuraEnabled
    public static List<LoyaltyLevel> getLoyaltyLevelDisplayInfo() {
        List<LoyaltyLevel> loyaltyLevels = new List<LoyaltyLevel>();

        for (Level__c level : [SELECT Name, Donation_Threshold__c, Description__c, Donation_Payment__c, Donation_Points__c FROM Level__c WHERE isActive__c = true AND isVisible__c = true ORDER BY Donation_Threshold__c ASC]) {
            LoyaltyLevel loyaltyLevel = new LoyaltyLevel();
            loyaltyLevel.levelId = level.Id;
            loyaltyLevel.levelName = level.Name;
            loyaltyLevel.levelThreshold = level.Donation_Threshold__c;
            loyaltyLevel.levelDescription = level.Description__c;
            loyaltyLevel.loyaltyCurrencyPerDonation = level.Donation_Payment__c;
            loyaltyLevel.loyaltyPointsPerDonation = level.Donation_Points__c;
            loyaltyLevels.add(loyaltyLevel);
        }

        return loyaltyLevels;
    }

    @AuraEnabled
    public static List<BadgeSetting> getLoyaltyBadgeDisplaySettings() {
        // TODO: We may want to add a fileName field on the Level__c object to make this more flexible
        Map<String, String> loyaltyTierNameToBadgeFileNamePrefix = new Map<String, String> {
            'Signature' => 'Signature',
            'VIP' => 'VIP',
            'Royal' => 'Royal'
        };

        // TODO: This is a hack to get the tests to pass. We should find a better way to do this.
        if (Test.isRunningTest()) {
            loyaltyTierNameToBadgeFileNamePrefix.put('Bronze', 'bronze');
            loyaltyTierNameToBadgeFileNamePrefix.put('Silver', 'silver');
            loyaltyTierNameToBadgeFileNamePrefix.put('Gold', 'gold');
        }

        List<BadgeSetting> badgeSettings = new List<BadgeSetting>();
        for (Level__c level : [SELECT Name FROM Level__c WHERE isActive__c = true AND isVisible__c = true ORDER BY Donation_Threshold__c ASC]) {
            BadgeSetting badgeSetting = new BadgeSetting();
            badgeSetting.badgeName = level.Name;
            badgeSetting.fullBadgeFileName = loyaltyTierNameToBadgeFileNamePrefix.get(level.Name) + '_Full';
            badgeSetting.noNameBadgeFileName = loyaltyTierNameToBadgeFileNamePrefix.get(level.Name) + '_Centered_Stars';

            badgeSettings.add(badgeSetting);
        }

        return badgeSettings;
    }

    public class LoyaltyLevel {
        @AuraEnabled
        public String levelId;

        @AuraEnabled
        public String levelName;

        @AuraEnabled
        public String levelDescription;

        @AuraEnabled
        public Decimal levelThreshold;

        @AuraEnabled
        public Decimal loyaltyCurrencyPerDonation;

        @AuraEnabled
        public Decimal loyaltyPointsPerDonation;
    }

    public class BadgeSetting {
        @AuraEnabled
        public String badgeName;

        @AuraEnabled
        public String fullBadgeFileName;

        @AuraEnabled
        public String noNameBadgeFileName;
    }
}