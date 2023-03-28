public without sharing class LoyaltyLevelService {
    private static Map<Id, Integer> loyaltyLevelIdToIndex;

    public static Integer getLoyaltyLevel(Id loyaltyLevelId) {
        if (loyaltyLevelIdToIndex == null) {
            loyaltyLevelIdToIndex = new Map<Id, Integer>();

            Integer loyaltyLevelIndex = 0;
            for(Level__c loyaltyLevelRecord : [
                SELECT Id
                FROM Level__c
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
        
        // The hard coded filter on the name is a temporary workaround, this'll need to be reworked once the level records have been updated
        for(Level__c queriedLevel : [SELECT Id, Name, Donation_Threshold__c, Description__c FROM Level__c WHERE Name NOT IN ('Normal Donor +15') ORDER BY Donation_Threshold__c ASC]) {
            LoyaltyLevel loyaltyLevel = new LoyaltyLevel();

            loyaltyLevel.levelId = queriedLevel.Id;
            loyaltyLevel.levelName = queriedLevel.Name;
            loyaltyLevel.levelThreshold = queriedLevel.Donation_Threshold__c;
            loyaltyLevel.levelDescription = queriedLevel.Description__c;

            loyaltyLevels.add(loyaltyLevel);
        }

        return loyaltyLevels;
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
}