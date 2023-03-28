public without sharing class DonorSelector {
    @AuraEnabled
    public static List<Account> searchVisitElgibleDonorByName(String nameSearchString, DateTime targetVisitDateString) {
        if (String.isEmpty(nameSearchString)) {
            return null;
        }

        return [
            SELECT Id, Name, PersonEmail, PersonMobilePhone, Soonest_Next_Visit__pc
            FROM Account
            WHERE Name LIKE :(nameSearchString + '%') AND
            RecordTypeId = :Schema.SObjectType.Account.getRecordTypeInfosByName().get('Donor').getRecordTypeId() AND
            Soonest_Next_Visit__pc <= :targetVisitDateString
        ];
    }

    public static List<AccountContactRelation> getDonorsForCenter(Id centerId) {
        return [
            SELECT ContactId
            FROM AccountContactRelation
            WHERE AccountId = :centerId AND Roles = 'Donor' AND IsActive = TRUE
        ];
    }

    @AuraEnabled
    public static DonorRewardsInfo getDonorRewardsInfo() {
        return new DonorRewardsInfo([
            SELECT Balance_Currency__c, Balance_Points__c, Loyalty_Level__r.Name, Loyalty_Level__r.Next_Level__r.Name, Loyalty_Level__r.Next_Level__r.Donation_Threshold__c,
                Total_Visits_365d__c
            FROM Contact 
            WHERE Id IN (SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()) LIMIT 1
        ]);
    }

    public class DonorRewardsInfo {
        @AuraEnabled
        public Decimal donorBalance;

        @AuraEnabled
        public Decimal donorPoints;

        @AuraEnabled
        public String currentLoyaltyLevel;

        @AuraEnabled
        public Decimal minimumWithdrawalAmount;

        @AuraEnabled
        public String nextLoyaltyLevel;

        @AuraEnabled
        public Decimal remainingVisitsForNextTier;

        public DonorRewardsInfo(Contact donorInfo) {
            this.donorBalance = donorInfo.Balance_Currency__c;
            this.donorPoints = donorInfo.Balance_Points__c;
            this.currentLoyaltyLevel = !String.isEmpty(donorInfo.Loyalty_Level__r.Name) ? donorInfo.Loyalty_Level__r.Name : 'Donor (Default)';

            Proesis_Wallet__c proesisWalletConfig = Proesis_Wallet__c.getOrgDefaults();
            this.minimumWithdrawalAmount = proesisWalletConfig.Minimum_Withdrawal__c;

            if (donorInfo.Loyalty_Level__r.Next_Level__r != null) {
                this.nextLoyaltyLevel = donorInfo.Loyalty_Level__r.Next_Level__r.Name;

                Decimal currentDonorVisitCount = (donorInfo.Total_Visits_365d__c != null) ? donorInfo.Total_Visits_365d__c : 0;
                this.remainingVisitsForNextTier = donorInfo.Loyalty_Level__r.Next_Level__r.Donation_Threshold__c - currentDonorVisitCount;
            }
        }
    }
}