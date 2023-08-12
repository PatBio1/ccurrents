List<Payment_Method__c> emptyPaymentMethods = new List<Payment_Method__c>();

for(Payment_Method__c pm : [SELECT Id, Donor__c, Partner_User_Id__c FROM Payment_Method__c WHERE Partner_User_Id__c = null LIMIT 1000]){
    pm.Partner_User_Id__c = pm.Donor__c;
    emptyPaymentMethods.add(pm);
}

update emptyPaymentMethods;