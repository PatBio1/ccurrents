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

        cancelPaymentMethod(targetPaymentMethod.Id);
    }

    @AuraEnabled
    public static void cancelPaymentMethod(String paymentMethodId) {
        List<Payment_Method__c> targetPaymentMethod = [
            SELECT Id, User_Requested_Replace_Card__c, Donor__c, Expiration__c 
            FROM Payment_Method__c 
            WHERE Id = :paymentMethodId 
            LIMIT 1
        ];

        if (targetPaymentMethod.isEmpty()) {
            throw new AuraHandledException('Payment method not found');
        }

        Payment_Method__c paymentMethod = targetPaymentMethod[0];
        if (paymentMethod.User_Requested_Replace_Card__c) {
            throw new AuraHandledException('Payment method already cancelled');
        }

        paymentMethod.User_Requested_Replace_Card__c = true;
        update paymentMethod;

        // Look for an existing visit, if we find one we need to attach a special note to the visit
        List<Visit__c> futureDonorVisits = [
            SELECT Id 
            FROM Visit__c 
            WHERE Donor__c = :paymentMethod.Donor__c AND 
                Status__c IN ('New', 'Scheduled') AND 
                Appointment_Datetime__c >= :System.now()
            ORDER BY Appointment_Datetime__c ASC
            LIMIT 1
        ];

        if (!futureDonorVisits.isEmpty()) {
            insert CancelCardController.createReplacePaymentMethodTask(
                futureDonorVisits[0].Id, targetPaymentMethod.Expiration__c, paymentMethod.Donor__c
            );
        }
    }

    public static Task createReplacePaymentMethodTask(Id targetReplacementVisitId, Date paymentExpirationDate, Id paymentDonorId) {
        Task replacePaymentMethodTask = new Task();
        replacePaymentMethodTask.Subject = Constants.REPLACE_PAYMENT_METHOD_TASK_SUBJECT;
        replacePaymentMethodTask.Description = 'The existing payment method for this donor has been cancelled. Please update the donor\'s payment method.';
        replacePaymentMethodTask.WhatId = targetReplacementVisitId;
        replacePaymentMethodTask.WhoId = paymentDonorId;
        replacePaymentMethodTask.ActivityDate = paymentExpirationDate;

        return replacePaymentMethodTask;
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