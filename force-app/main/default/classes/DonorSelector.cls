public without sharing class DonorSelector {
    @AuraEnabled
    public static List<DonorSearchResult> searchVisitElgibleDonorByName(String nameSearchString, DateTime targetVisitDateString, Boolean allowLoyaltyDonors, Boolean allowDonors, String centerAccountId) {
        if (String.isEmpty(nameSearchString)) {
            return null;
        }

        String centerTimeZoneKey = [SELECT Center_Timezone__c FROM Account WHERE Id = :centerAccountId LIMIT 1]?.Center_Timezone__c;
        DateTime adjustedVisitDateTime = Util.getTimeZoneDateTime(targetVisitDateString.date(), targetVisitDateString.time(), centerTimeZoneKey);

        adjustedVisitDateTime = adjustedVisitDateTime.addHours(23 - adjustedVisitDateTime.hourGmt());
        adjustedVisitDateTime = adjustedVisitDateTime.addMinutes(59 - adjustedVisitDateTime.minuteGmt());
        adjustedVisitDateTime = adjustedVisitDateTime.addSeconds(59 - adjustedVisitDateTime.secondGmt());

        List<DonorSearchResult> donorSearchResults = new List<DonorSearchResult>();
        for(Account donor : [
            SELECT Id, Name, PersonEmail, PersonMobilePhone, Soonest_Next_Visit__pc, Loyalty_Level__pc, Loyalty_Level__pr.Name, PersonContactId
            FROM Account
            WHERE Name LIKE :(nameSearchString + '%') AND
                RecordTypeId = :Schema.SObjectType.Account.getRecordTypeInfosByName().get('Donor').getRecordTypeId()
            ORDER BY Name ASC
        ]) {
            DonorSearchResult newSearchResult = new DonorSearchResult(donor);

            Integer loyaltyLevel = LoyaltyLevelService.getLoyaltyLevel(donor.Loyalty_Level__pc);
            Datetime adjustedSoonestNextVisit = Datetime.newInstanceGmt(donor.Soonest_Next_Visit__pc.date(), donor.Soonest_Next_Visit__pc.time());
            newSearchResult.setDonorSoonestNextVisit(donor.Soonest_Next_Visit__pc, centerTimeZoneKey);

            if (
                (loyaltyLevel > 0 && !allowLoyaltyDonors) ||
                ((loyaltyLevel == 0 || String.isEmpty(donor.Loyalty_Level__pc)) && !allowDonors)
            ) {
                newSearchResult.setCantScheduleReason(Constants.CANT_SCHEDULE_LOYALTY_MESSAGE);
            } else {
                System.debug(adjustedSoonestNextVisit);
                System.debug(adjustedVisitDateTime);

                // if (adjustedSoonestNextVisit != null && adjustedSoonestNextVisit > adjustedVisitDateTime) {
                //     newSearchResult.setCantScheduleReason(String.format(Constants.CANT_SCHEDULE_SOONEST_NEXT_VISIT_MESSAGE, new List<Object> { adjustedSoonestNextVisit.format('MM/dd/yyyy') }));
                // }
            } 

            donorSearchResults.add(newSearchResult);
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
        List<Contact> targetDonors = [
            SELECT Id, Name, Last_Onbe_Balance_Update__c, Onbe_Balance__c, Balance_Points__c, Redeemed_Points__c, Total_Visits_365d__c,
                Loyalty_Level__r.Name, Loyalty_Level__r.Donation_Threshold__c, 
                Loyalty_Level__r.Next_Level__r.Name, Loyalty_Level__r.Next_Level__r.Donation_Threshold__c, (
                    SELECT Id, Expiration__c, Card_Number__c
                    FROM Payment_Methods__r
                    WHERE Is_Active__c = true AND isDefault__c = true AND Is_Expired__c = false AND User_Requested_Replace_Card__c = false
                    LIMIT 1
                )
            FROM Contact 
            WHERE Id IN (SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId())
            LIMIT 1
        ];

        if (targetDonors == null || targetDonors.isEmpty()) {
            return null;
        }

        Proesis_Settings__c proesisSettings = Proesis_Settings__c.getOrgDefaults();
        if (proesisSettings.Payment_Service_Balance_Max_Freq__c == null) {
            proesisSettings.Payment_Service_Balance_Max_Freq__c = 3;
        }

        Contact targetDonor = targetDonors[0];
        Datetime targetDonorLastBalanceUpdate = targetDonor.Last_Onbe_Balance_Update__c != null ? targetDonor.Last_Onbe_Balance_Update__c.addHours((Integer)proesisSettings.Payment_Service_Balance_Max_Freq__c) : null;

        if (targetDonor.Payment_Methods__r.size() > 0 && (targetDonorLastBalanceUpdate == null || System.now() >= targetDonorLastBalanceUpdate)) {
            OnbePaymentService paymentService = new OnbePaymentService();
            Decimal donorOnbeBalance;

            try {
                donorOnbeBalance = paymentService.getBalance(targetDonor.Id);
            } catch(Exception e) {
                throw new AuraHandledException('Unable to retrieve donor balance. Please try again later.');
            }

            targetDonor.Onbe_Balance__c = donorOnbeBalance == null ? 0 : donorOnbeBalance;
            targetDonor.Last_Onbe_Balance_Update__c = System.now();

            update targetDonor;
        }

        return new DonorRewardsInfo(targetDonor);
    }

    public class DonorSearchResult {
        @AuraEnabled
        public String donorId;
        @AuraEnabled
        public String donorContactId;
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
        @AuraEnabled
        public String cantScheduleReason;
        @AuraEnabled
        public String soonestNextVisitTimezone;

        public DonorSearchResult(Account donor) {
            this.donorId = donor.Id;
            this.donorContactId = donor.PersonContactId;
            this.donorName = donor.Name;
            this.donorEmail = donor.PersonEmail;
            this.donorPhone = donor.PersonMobilePhone;
            this.donorLoyaltyLevel = (!String.isEmpty(donor.Loyalty_Level__pr.Name)) ? donor.Loyalty_Level__pr.Name : 'Donor (Default)';
        }

        public void setCantScheduleReason(String reason) {
            this.cantScheduleReason = reason;
        }

        public void setDonorSoonestNextVisit(DateTime soonestNextVisit, String timezone) {
            this.donorSoonestNextVisit = soonestNextVisit;
            this.soonestNextVisitTimezone = timezone;
        }
    }

    public class DonorRewardsInfo {
        @AuraEnabled
        public String donorId;
        
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
        public Decimal pointsToDollarsConversionRate;

        @AuraEnabled
        public Decimal dollarIncrementAmount;

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

        @AuraEnabled
        public String cardNumber4Digits;

        @AuraEnabled 
        public String cardNumberExpiration;

        public DonorRewardsInfo(Contact donorInfo) {
            this.donorId = donorInfo.Id;
            this.donorName = donorInfo.Name;
            this.donorBalance = donorInfo.Onbe_Balance__c == null ? 0 : donorInfo.Onbe_Balance__c;

            Decimal pointsBalance = donorInfo.Balance_Points__c == null ? 0 : donorInfo.Balance_Points__c;
            Decimal redeemedPoints = donorInfo.Redeemed_Points__c == null ? 0 : donorInfo.Redeemed_Points__c;
            this.donorPoints = pointsBalance - redeemedPoints;

            this.currentLoyaltyLevel = !String.isEmpty(donorInfo.Loyalty_Level__r.Name) ? donorInfo.Loyalty_Level__r.Name : 'Donor (Default)';
            this.donorVisitCount = (donorInfo.Total_Visits_365d__c != null) ? donorInfo.Total_Visits_365d__c : 0;
            this.currentTierDonationThreshold = (donorInfo.Loyalty_Level__r.Donation_Threshold__c != null) ? donorInfo.Loyalty_Level__r.Donation_Threshold__c : 0;
            this.nextTierDonationThreshold = (donorInfo.Loyalty_Level__r.Next_Level__r.Donation_Threshold__c != null) ? donorInfo.Loyalty_Level__r.Next_Level__r.Donation_Threshold__c : 0;

            Proesis_Wallet__c proesisWalletConfig = Proesis_Wallet__c.getOrgDefaults();
            this.minimumWithdrawalAmount = proesisWalletConfig.Minimum_Withdrawal__c;
            this.pointsToDollarsConversionRate = (proesisWalletConfig.Points_to_Dollar__c != null) ? proesisWalletConfig.Points_to_Dollar__c : 100;
            this.dollarIncrementAmount = (proesisWalletConfig.Dollar_Increment__c != null) ? proesisWalletConfig.Dollar_Increment__c : 20;

            if (donorInfo.Loyalty_Level__r.Next_Level__r != null) {
                this.nextLoyaltyLevel = donorInfo.Loyalty_Level__r.Next_Level__r.Name;
                this.remainingVisitsForNextTier = donorInfo.Loyalty_Level__r.Next_Level__r.Donation_Threshold__c - this.donorVisitCount;
            }

            Payment_Method__c defaultPaymentMethod = donorInfo.Payment_Methods__r != null && !donorInfo.Payment_Methods__r.isEmpty() ? donorInfo.Payment_Methods__r[0] : null;
            if (defaultPaymentMethod != null) {
                this.cardNumber4Digits = defaultPaymentMethod.Card_Number__c;

                if (defaultPaymentMethod.Expiration__c != null) {
                    String expirationDate = defaultPaymentMethod.Expiration__c.month() < 10 ? '0' + defaultPaymentMethod.Expiration__c.month() : String.valueOf(defaultPaymentMethod.Expiration__c.month());
                    expirationDate += '/' + String.valueOf(defaultPaymentMethod.Expiration__c.year());

                    this.cardNumberExpiration = expirationDate;
                }
            }
        }
    }
}