public without sharing class LoyaltyLevelService {

    private static Map<Id, Integer> loyaltyLevelIdToIndex;

    public static Level__c getDefault() {
        return [
            SELECT
                Id
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

        for (Level__c level : [SELECT Name, Donation_Threshold__c, Description__c FROM Level__c WHERE isActive__c = true AND isVisible__c = true ORDER BY Donation_Threshold__c ASC]) {
            LoyaltyLevel loyaltyLevel = new LoyaltyLevel();
            loyaltyLevel.levelId = level.Id;
            loyaltyLevel.levelName = level.Name;
            loyaltyLevel.levelThreshold = level.Donation_Threshold__c;
            loyaltyLevel.levelDescription = level.Description__c;
            loyaltyLevels.add(loyaltyLevel);
        }

        return loyaltyLevels;
    }

    @AuraEnabled
    public static List<BadgeSetting> getLoyaltyBadgeDisplaySettings() {
        // TODO: We may want to add a fileName field on the Level__c object to make this more flexible
        Map<String, String> loyaltyTierNameToBadgeFileName = new Map<String, String> {
            'Donor (Default)' => 'default',
            'Normal Donor +15' => 'normal',
            'Signature' => 'VIP',
            'VIP' => 'royal',
            'Royal' => 'signature'
        };

        List<BadgeSetting> badgeSettings = new List<BadgeSetting>();
        for (Level__c level : [SELECT Name FROM Level__c WHERE isActive__c = true AND isVisible__c = true ORDER BY Donation_Threshold__c ASC]) {
            BadgeSetting badgeSetting = new BadgeSetting();
            badgeSetting.badgeName = level.Name;
            badgeSetting.badgeFileName = loyaltyTierNameToBadgeFileName.get(level.Name);

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
    }

    public class BadgeSetting {
        @AuraEnabled
        public String badgeName;

        @AuraEnabled
        public String badgeFileName;
    }
}