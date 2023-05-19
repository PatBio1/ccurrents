public without sharing class CancelCardController {
    @AuraEnabled
    public static PaymentMethod getDonorDefaultPaymentMethod(String donorId) {
        Payment_Method__c targetPaymentMethod;

        try {
            targetPaymentMethod = [
                SELECT Id, Name, Card_Number__c 
                FROM Payment_Method__c 
                WHERE Donor__c IN (SELECT Id FROM Contact WHERE AccountId = :donorId) AND
                    isDefault__c = true AND
                    Is_Active__c = true
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        
        PaymentMethod paymentMethod = new PaymentMethod();
        paymentMethod.id = targetPaymentMethod.Id;
        paymentMethod.name = targetPaymentMethod.Name;
        paymentMethod.cardNumber4Digits = targetPaymentMethod.Card_Number__c.left(4);

        return paymentMethod;
    }

    @AuraEnabled
    public static void cancelDonorActivePayment() {
        Payment_Method__c targetPaymentMethod;
        
        try {
            targetPaymentMethod = [
                SELECT Id
                FROM Payment_Method__c
                WHERE Donor__c IN (SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()) AND
                    Is_Active__c = true
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
        } catch(Exception e) {
            throw new AuraHandledException('Error while getting donor active payment method: ' + e.getMessage());
        }

        // As of writing this comment, the method is only used in the lost card modal. So we can assume a lost card code
        cancelPaymentMethod(targetPaymentMethod.Id, Constants.ONBE_REISSUE_CARD_LOST_CODE);
    }

    @AuraEnabled
    public static void cancelPaymentMethod(String paymentMethodId, String reissueCode) {
        try {
            OnbePaymentService paymentService = new OnbePaymentService();
            paymentService.reissueCard(paymentMethodId, reissueCode);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        // Given a successful response, deactivate the payment method, also unmark as default
        update new Payment_Method__c(
            Id = paymentMethodId,
            Is_Active__c = false,
            isDefault__c = false
        );
    }

    public class PaymentMethod {
        @AuraEnabled
        public String id { get; set; }

        @AuraEnabled
        public String name { get; set; }

        @AuraEnabled
        public String cardNumber4Digits { get; set; }
    }
}