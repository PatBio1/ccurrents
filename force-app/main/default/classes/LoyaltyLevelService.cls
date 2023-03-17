public with sharing class LoyaltyLevelService {
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
}