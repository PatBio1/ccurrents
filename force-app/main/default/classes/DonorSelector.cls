public without sharing class DonorSelector {
    @AuraEnabled
    public static List<DonorSearchResult> searchVisitElgibleDonorByName(String nameSearchString, DateTime targetVisitDateString, Boolean allowLoyaltyDonors, Boolean allowDonors) {
        if (String.isEmpty(nameSearchString)) {
            return null;
        }

        List<DonorSearchResult> donorSearchResults = new List<DonorSearchResult>();

        // We'll search for eligible donors up to the end of the day of the target visit date as the soonest next visit time component doesn't matter
        DateTime adjustedVisitDateTime = targetVisitDateString.addHours(23);
        adjustedVisitDateTime = adjustedVisitDateTime.addMinutes(59);
        adjustedVisitDateTime = adjustedVisitDateTime.addSeconds(59);

        for(Account donor : [
            SELECT Id, Name, PersonEmail, PersonMobilePhone, Soonest_Next_Visit__pc, Loyalty_Level__pc, Loyalty_Level__pr.Name
            FROM Account
            WHERE Name LIKE :(nameSearchString + '%') AND
                RecordTypeId = :Schema.SObjectType.Account.getRecordTypeInfosByName().get('Donor').getRecordTypeId() AND
                Soonest_Next_Visit__pc <= :adjustedVisitDateTime
        ]) {
            Integer loyaltyLevel = LoyaltyLevelService.getLoyaltyLevel(donor.Loyalty_Level__pc);

            if (
                (loyaltyLevel > 0 && !allowLoyaltyDonors) ||
                ((loyaltyLevel == 0 || String.isEmpty(donor.Loyalty_Level__pc)) && !allowDonors)
            ) {
                continue;
            }

            donorSearchResults.add(new DonorSearchResult(donor));
        }

        return donorSearchResults;
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
        List<Contact> targetDonor = [
            SELECT Name, Balance_Currency__c, Balance_Points__c, Total_Visits_365d__c,
                Loyalty_Level__r.Name, Loyalty_Level__r.Donation_Threshold__c, 
                Loyalty_Level__r.Next_Level__r.Name, Loyalty_Level__r.Next_Level__r.Donation_Threshold__c
            FROM Contact 
            WHERE Id IN (SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId())
            LIMIT 1
        ];

        if (targetDonor == null || targetDonor.isEmpty()) {
            return null;
        }

        return new DonorRewardsInfo(targetDonor[0]);
    }

    public class DonorSearchResult {
        @AuraEnabled
        public String donorId;
        @AuraEnabled
        public String donorName;
        @AuraEnabled
        public String donorEmail;
        @AuraEnabled
        public String donorPhone;
        @AuraEnabled
        public DateTime donorSoonestNextVisit;
        @AuraEnabled
        public String donorLoyaltyLevel;

        public DonorSearchResult(Account donor) {
            this.donorId = donor.Id;
            this.donorName = donor.Name;
            this.donorEmail = donor.PersonEmail;
            this.donorPhone = donor.PersonMobilePhone;
            this.donorSoonestNextVisit = donor.Soonest_Next_Visit__pc;
            this.donorLoyaltyLevel = (!String.isEmpty(donor.Loyalty_Level__pr.Name)) ? donor.Loyalty_Level__pr.Name : 'Donor (Default)';
        }
    }

    public class DonorRewardsInfo {
        @AuraEnabled
        public String donorName;

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
        public Decimal donorVisitCount;

        @AuraEnabled
        public Decimal currentTierDonationThreshold;

        @AuraEnabled
        public Decimal nextTierDonationThreshold;

        @AuraEnabled
        public Decimal remainingVisitsForNextTier;

        public DonorRewardsInfo(Contact donorInfo) {
            this.donorName = donorInfo.Name;
            this.donorBalance = donorInfo.Balance_Currency__c;
            this.donorPoints = donorInfo.Balance_Points__c;
            this.currentLoyaltyLevel = !String.isEmpty(donorInfo.Loyalty_Level__r.Name) ? donorInfo.Loyalty_Level__r.Name : 'Donor (Default)';
            this.donorVisitCount = (donorInfo.Total_Visits_365d__c != null) ? donorInfo.Total_Visits_365d__c : 0;
            this.currentTierDonationThreshold = (donorInfo.Loyalty_Level__r.Donation_Threshold__c != null) ? donorInfo.Loyalty_Level__r.Donation_Threshold__c : 0;
            this.nextTierDonationThreshold = (donorInfo.Loyalty_Level__r.Next_Level__r.Donation_Threshold__c != null) ? donorInfo.Loyalty_Level__r.Next_Level__r.Donation_Threshold__c : 0;

            Proesis_Wallet__c proesisWalletConfig = Proesis_Wallet__c.getOrgDefaults();
            this.minimumWithdrawalAmount = proesisWalletConfig.Minimum_Withdrawal__c;

            if (donorInfo.Loyalty_Level__r.Next_Level__r != null) {
                this.nextLoyaltyLevel = donorInfo.Loyalty_Level__r.Next_Level__r.Name;
                this.remainingVisitsForNextTier = donorInfo.Loyalty_Level__r.Next_Level__r.Donation_Threshold__c - this.donorVisitCount;
            }
        }
    }
}