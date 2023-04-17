public with sharing class ExceptionPaymentController {
    @AuraEnabled
    public static void createExceptionPayment(Id donorId, Id visitId, Id exceptionRateId) {
        DonationService.createExceptionTransaction(new DonationService.DonationExceptionRequest(donorId, visitId, exceptionRateId));
    }

    @AuraEnabled
    public static VisitExceptionPaymentInfo getBaseVisitExceptionPaymentInfo(Id targetVisitId) {
        if (String.isEmpty(targetVisitId)) {
            return null;
        }

        Visit__c targetVisit = [
            SELECT Id, Appointment_Datetime__c, Donor__c, Donor__r.Name, Center_Donation_Type__r.Center__r.Name, Center_Donation_Type__r.Center__c, Center_Donation_Type__r.Donation_Type__c
            FROM Visit__c
            WHERE Id = :targetVisitId
            LIMIT 1
        ];

        List<Rate__c> availableCenterExceptionRates = [
            SELECT Id, Description__c, Base_Payment__c 
            FROM Rate__c 
            WHERE Center__c = :targetVisit.Center_Donation_Type__r.Center__c AND 
                Donation_Type__c = :targetVisit.Center_Donation_Type__r.Donation_Type__c AND 
                Type__c = 'Exception'
        ];

        return new VisitExceptionPaymentInfo(targetVisit, availableCenterExceptionRates);
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
        public Datetime visitDatetime;

        @AuraEnabled
        public List<ExceptionPaymentType> availableExceptionPaymentTypes;

        public VisitExceptionPaymentInfo(Visit__c targetVisit, List<Rate__c> availableCenterExceptionRates) {
            this.visitId = targetVisit.Id;
            this.visitDonorId = targetVisit.Donor__c;
            this.visitDonorName = targetVisit.Donor__r.Name;
            this.visitCenterName = targetVisit.Center_Donation_Type__r.Center__r.Name;
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