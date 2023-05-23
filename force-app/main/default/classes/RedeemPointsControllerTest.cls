@IsTest
public without sharing class RedeemPointsControllerTest {
    @TestSetup
    static void createTestData() {
        Account testDonorAccount = TestUtil.createDonor('123-456');
        insert testDonorAccount;

        Contact testDonorContact = [SELECT Id FROM Contact WHERE AccountId = :testDonorAccount.Id LIMIT 1];

        Transaction__c debitPointTransaction = new Transaction__c(
            Donor__c = testDonorContact.Id,
            Type__c = 'Debit',
            Status__c = 'Complete'
        );
        insert debitPointTransaction;

        Txn_Line_Item__c pointLineItem = new Txn_Line_Item__c(
            Transaction__c = debitPointTransaction.Id,
            Type__c = 'Points',
            Unit_Cost__c = 3000,
            Quantity__c = 1
        );
        insert pointLineItem;

        Payment_Method__c donorPaymentMethod = new Payment_Method__c(
            Name = 'Test Payment Method',
            Donor__c = testDonorContact.Id,
            Account_Token__c = '1050',
            Account_Number__c = '4968712468235235',
            Card_Number__c = '7890',
            Is_Active__c = true,
            isDefault__c = true
        );
        insert donorPaymentMethod;

        Proesis_Wallet__c proesisWallet = Proesis_Wallet__c.getOrgDefaults();
        proesisWallet.Points_to_Dollar__c = 100;
        proesisWallet.Minimum_Withdrawal__c = 2000;
        insert proesisWallet;
    }

    @IsTest
    static void testRedeemPoints() {
        List<Contact> testDonor = [SELECT Id FROM Contact WHERE Account.DonorId__c != null LIMIT 1];
        Decimal pointsToRedeem = 2000;

        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        System.runAs(TestUtil.createExperienceUserFromContactId(testDonor[0].Id)) {
            RedeemPointsController.redeemPoints(testDonor[0].Id, pointsToRedeem);
        }
        Test.stopTest();

        testDonor = [
            SELECT Id, Redeemed_Points__c, (
                SELECT Id, Type__c, Status__c, SubType__c
                FROM Transactions__r
                WHERE SubType__c = 'Point Redemption'
            ) 
            FROM Contact 
            WHERE Id = :testDonor[0].Id
        ];

        Assert.areEqual(pointsToRedeem, testDonor[0].Redeemed_Points__c, 'Donor should have 2000 points redeemed');
        Assert.areEqual(2, testDonor[0].Transactions__r.size(), 'Donor should have 3 transactions after redeeming points');

        for(Transaction__c donorTransaction : testDonor[0].Transactions__r) {
            Assert.areEqual('Complete', donorTransaction.Status__c, 'Redeem points transactions should be complete without error');
            Assert.areEqual('Point Redemption', donorTransaction.SubType__c, 'Redeem points transactions should have a sub type of Point Redemption');
        }

        List<Txn_Line_Item__c> pointsRedeemedLineItems = [SELECT Id, Type__c, Unit_Cost__c FROM Txn_Line_Item__c WHERE Item__c = 'PlasmaPoints Redeemed'];
        Map<String, Integer> lineItemCountByType = new Map<String, Integer>();

        Proesis_Wallet__c proesisWallet = Proesis_Wallet__c.getOrgDefaults();

        for(Txn_Line_Item__c pointsRedeemedLineItem : pointsRedeemedLineItems) {
            Integer runningTypeCount = lineItemCountByType.get(pointsRedeemedLineItem.Type__c);
            if (runningTypeCount == null) {
                runningTypeCount = 0;
            }
            runningTypeCount += 1;

            if (pointsRedeemedLineItem.Type__c == 'Points') {
                Assert.areEqual(pointsToRedeem, pointsRedeemedLineItem.Unit_Cost__c, 'Points redeemed line item should have a unit cost of 2000');    
            } else if (pointsRedeemedLineItem.Type__c == 'Currency') {
                Assert.areEqual(Math.round(pointsToRedeem / proesisWallet.Points_to_Dollar__c), pointsRedeemedLineItem.Unit_Cost__c, 'Points redeemed line item should have a unit cost of 20');
            }

            lineItemCountByType.put(pointsRedeemedLineItem.Type__c, runningTypeCount);
        }

        Assert.areEqual(1, lineItemCountByType.get('Points'), 'There should be 1 point line items');
        Assert.areEqual(2, lineItemCountByType.get('Currency'), 'There should be 2 currency line item');
    }
}