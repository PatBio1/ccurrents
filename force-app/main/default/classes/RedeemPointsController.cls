public without sharing class RedeemPointsController {
    @AuraEnabled
    public static void redeemPoints(String donorId, Decimal pointsToRedeem) {
        List<Payment_Method__c> donorPaymentMethod = [SELECT Id, Account_Number__c FROM Payment_Method__c WHERE Donor__c = :donorId AND Is_Active__c = true AND isDefault__c = true LIMIT 1];
        String accountNumber = (donorPaymentMethod != null && donorPaymentMethod.size() > 0) ? donorPaymentMethod[0].Account_Number__c : null;

        Proesis_Wallet__c proesisWallet = Proesis_Wallet__c.getOrgDefaults();
        Decimal pointsToDollars = (proesisWallet.Points_to_Dollar__c != null) ? proesisWallet.Points_to_Dollar__c : 100;
        Decimal dollorsToCredit = Math.round(pointsToRedeem / pointsToDollars);
        Decimal roundedPointsToRedeem = dollorsToCredit * pointsToDollars;
        
        // Create the initial credit transactions
        Transaction__c creditTransaction = new Transaction__c(Donor__c = donorId, Type__c = 'Credit', SubType__c = 'Point Redemption', Status__c = 'Complete');
        insert creditTransaction;

        List<Txn_Line_Item__c> transactionLineItems = new List<Txn_Line_Item__c>();
        transactionLineItems.add(new Txn_Line_Item__c(
            Transaction__c = creditTransaction.Id, 
            Type__c = 'Currency', 
            Unit_Cost__c = dollorsToCredit,
            Quantity__c = 1,
            Item__c = 'PlasmaPoints Redeemed'
        ));
        insert transactionLineItems;

        // Update points redeemed on the donor contact's record
        Contact targetContact;
        try {
            targetContact = [SELECT Id, Redeemed_Points__c, Last_Onbe_Balance_Update__c FROM Contact WHERE Id = :donorId LIMIT 1];
        } catch(Exception e) {
            System.debug(e);
            throw new AuraHandledException('Unable to find donor contact');
        }

        targetContact.Redeemed_Points__c = (targetContact.Redeemed_Points__c != null) ? targetContact.Redeemed_Points__c + roundedPointsToRedeem : roundedPointsToRedeem;
        targetContact.Last_Onbe_Balance_Update__c = null;
        update targetContact;

        // Queue up the addFunds callout to Onbe
        List<DonorCompInvocable.AddFundsRequest> addFundsRequests = new List<DonorCompInvocable.AddFundsRequest>();

        DonorCompInvocable.AddFundsRequest redeemPointsRequest = new DonorCompInvocable.AddFundsRequest(donorId, null, accountNumber, 'Point Redemption');
        redeemPointsRequest.comments.add('PlasmaPoints Redeemed');
        redeemPointsRequest.addLineItem('PlasmaPoints Redeemed', 'Currency', dollorsToCredit);
        redeemPointsRequest.addLineItem('PlasmaPoints Redeemed', 'Points', roundedPointsToRedeem);

        addFundsRequests.add(redeemPointsRequest);

        Database.executeBatch(new AddFundsBatchable(addFundsRequests));
    }
}