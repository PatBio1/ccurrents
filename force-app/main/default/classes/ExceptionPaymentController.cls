public without sharing class ExceptionPaymentController {
    @AuraEnabled
    public static void createExceptionPayment(Id donorId, Id visitId, Id exceptionRateId) {
        try {
            DonationService.createExceptionTransaction(new DonationService.DonationExceptionRequest(donorId, visitId, exceptionRateId));
        } catch(Exception e) {
            AuraHandledException newException = new AuraHandledException(e.getMessage());
            newException.setMessage(e.getMessage()); // Without this line, the error message returns 'Script-thrown exception' in the apex unit test

            throw newException;
        }
    }

    @AuraEnabled
    public static VisitExceptionPaymentInfo getBaseVisitExceptionPaymentInfo(Id targetVisitId) {
        if (String.isEmpty(targetVisitId)) {
            return null;
        }

        Visit__c targetVisit = [
            SELECT Id, Appointment_Datetime__c, Donor__c, Donor__r.Name, Center_Donation_Type__r.Center__c, Center_Donation_Type__r.Donation_Type__c
            FROM Visit__c
            WHERE Id = :targetVisitId
            LIMIT 1
        ];

        Account targetCenterAccount = [
            SELECT Id, Name, Max_Dollar_Per_Day__c, Individual_Exception_Limit__c
            FROM Account
            WHERE Id = :targetVisit.Center_Donation_Type__r.Center__c AND 
                RecordType.DeveloperName = 'Center'
            LIMIT 1
        ];

        List<AggregateResult> centerExceptionTransactionCurrencySum = [
            SELECT Visit__r.Center_Donation_Type__r.Center__c, SUM(Amount_Currency__c) sum
            FROM Transaction__c
            WHERE Visit__r.Center_Donation_Type__r.Center__c = :targetCenterAccount.Id AND 
                Type__c = 'Debit' AND
                SubType__c = 'Exception' AND 
                CreatedDate = TODAY
            GROUP BY Visit__r.Center_Donation_Type__r.Center__c
        ];

        List<AggregateResult> individualExceptionTransactionCurrencySum = [
            SELECT Visit__r.Donor__c, SUM(Amount_Currency__c) sum
            FROM Transaction__c
            WHERE Visit__r.Donor__c = :targetVisit.Donor__c AND 
                Type__c = 'Debit' AND
                SubType__c = 'Exception' AND 
                CreatedDate = TODAY
            GROUP BY Visit__r.Donor__c
        ];

        List<Rate__c> availableCenterExceptionRates = [
            SELECT Id, Description__c, Base_Payment__c 
            FROM Rate__c 
            WHERE Center__c = :targetVisit.Center_Donation_Type__r.Center__c AND 
                Donation_Type__c = :targetVisit.Center_Donation_Type__r.Donation_Type__c AND 
                Type__c = 'Exception'
        ];

        Decimal usedDayLimit = (centerExceptionTransactionCurrencySum != null && centerExceptionTransactionCurrencySum.size() > 0) ? (Decimal)centerExceptionTransactionCurrencySum[0].get('sum') : 0;
        Decimal usedIndividualLimit = (individualExceptionTransactionCurrencySum != null && individualExceptionTransactionCurrencySum.size() > 0) ? (Decimal)individualExceptionTransactionCurrencySum[0].get('sum') : 0;
        return new VisitExceptionPaymentInfo(
            targetVisit, 
            targetCenterAccount, 
            usedDayLimit,
            usedIndividualLimit, 
            availableCenterExceptionRates
        );
    }

    public class VisitExceptionPaymentInfo {
        @AuraEnabled
        public String visitId;

        @AuraEnabled
        public String visitDonorId;

        @AuraEnabled
        public String visitDonorName;

        @AuraEnabled
        public String visitCenterName;

        @AuraEnabled
        public Decimal visitDayLimit;
        @AuraEnabled
        public Decimal visitDayRemainingLimit;

        @AuraEnabled
        public Decimal visitIndividualLimit;
        @AuraEnabled
        public Decimal visitIndividualRemainingLimit;

        @AuraEnabled
        public Datetime visitDatetime;

        @AuraEnabled
        public List<ExceptionPaymentType> availableExceptionPaymentTypes;

        public VisitExceptionPaymentInfo(Visit__c targetVisit, Account targetCenter, Decimal usedDayLimit, Decimal usedIndividualLimit, List<Rate__c> availableCenterExceptionRates) {
            this.visitId = targetVisit.Id;
            this.visitDonorId = targetVisit.Donor__c;
            this.visitDonorName = targetVisit.Donor__r.Name;
            this.visitCenterName = targetCenter.Name;
            this.visitDayLimit = (targetCenter.Max_Dollar_Per_Day__c == null) ? 0 : targetCenter.Max_Dollar_Per_Day__c;
            this.visitDayRemainingLimit = visitDayLimit - usedDayLimit;
            this.visitIndividualLimit = (targetCenter.Individual_Exception_Limit__c == null) ? 0 : targetCenter.Individual_Exception_Limit__c;
            this.visitIndividualRemainingLimit = visitIndividualLimit - usedIndividualLimit;
            this.visitDatetime = targetVisit.Appointment_Datetime__c;

            this.availableExceptionPaymentTypes = new List<ExceptionPaymentType>();
            for (Rate__c rate : availableCenterExceptionRates) {
                this.availableExceptionPaymentTypes.add(new ExceptionPaymentType(rate));
            }
        }
    }

    public class ExceptionPaymentType {
        @AuraEnabled
        public String id;

        @AuraEnabled
        public String description;

        @AuraEnabled
        public Decimal amount;

        public ExceptionPaymentType(Rate__c sourceRateRecord) {
            this.id = sourceRateRecord.Id;
            this.description = sourceRateRecord.Description__c;
            this.amount = sourceRateRecord.Base_Payment__c;
        }
    }
}