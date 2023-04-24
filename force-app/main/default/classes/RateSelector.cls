public without sharing class RateSelector {
    @AuraEnabled
    public static Rate getCenterRate(Id centerId, String targetDonationType) {
        List<Rate__c> targetCenterRateRecord;
        Level__c defaultLevel;

        try {
            defaultLevel = LoyaltyLevelService.getDefault();

            targetCenterRateRecord = [
                SELECT Id, Base_Payment__c, Donation_Type__r.Name, Center__c, UOM__c 
                FROM Rate__c 
                WHERE Center__c = :centerId AND 
                    Donation_Type__c IN (SELECT Id FROM Donation_Type__c WHERE Name = :targetDonationType)
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        if (targetCenterRateRecord.isEmpty()) {
            throw new AuraHandledException('No rate found for ' + targetDonationType + ' at ' + centerId);
        }

        Rate targetCenterRate = new Rate(targetCenterRateRecord[0]);
        if (defaultLevel != null) {
            targetCenterRate.basePayment += defaultLevel.Donation_Payment__c;
            targetCenterRate.basePoints += defaultLevel.Donation_Points__c;
        }

        return targetCenterRate;
    }

    public class Rate {
        @AuraEnabled
        public String id {get; set;}

        @AuraEnabled
        public String center {get; set;}

        @AuraEnabled
        public String donationType {get; set;}

        @AuraEnabled
        public Decimal basePayment {get; set;}

        @AuraEnabled
        public Decimal basePoints {get; set;}

        @AuraEnabled
        public String uom {get; set;}

        public Rate(Rate__c rate) {
            this.id = rate.Id;
            this.center = rate.Center__c;
            this.donationType = rate.Donation_Type__r.Name;
            this.basePayment = rate.Base_Payment__c;
            this.uom = rate.UOM__c;

            this.basePoints = 0;
        }
    }
}