@IsTest
public class TxnLineItemTriggerHandlerTest {
    static Integer NUMBER_OF_TRANSACTIONS = 201;

    @TestSetup
    static void makeData() {
        // Account of type center
        Account center = new Account();
        center.Name = 'Test Center';
        center.RecordTypeId = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Center' LIMIT 1].Id;
        insert center;

        // Donation Type
        Donation_Type__c donationType = new Donation_Type__c();
        donationType.Name = 'Test Donation Type';
        insert donationType;

        // Center Donation Type
        Center_Donation_Type__c centerDonationType = new Center_Donation_Type__c();
        centerDonationType.Center__c = center.Id;
        centerDonationType.Donation_Type__c = donationType.Id;
        centerDonationType.isActive__c = true;
        insert centerDonationType;

        // Create a transaction
        List<Contact> donors = new List<Contact>();
        // Id donorRecordTypeId = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Donor' LIMIT 1].Id;

        for(Integer i = 0; i < NUMBER_OF_TRANSACTIONS; i++) {
            Contact donor = new Contact();
            donor.FirstName = 'Test Donor' + i;
            donor.LastName = 'DonorLast' + i;
            donors.add(donor);
        }
        insert donors;

        List<Visit__c> visits = new List<Visit__c>();
        for(Integer i = 0; i < NUMBER_OF_TRANSACTIONS; i++) {
            Visit__c visit = new Visit__c();
            visit.Donor__c = donors[i].Id;
            visit.Center_Donation_Type__c = centerDonationType.Id;
            visit.Status__c = 'Complete';
            visit.Outcome__c = 'Donation';
            visits.add(visit);
        }
        insert visits;

        List<Transaction__c> txnRecords = new List<Transaction__c>();
        for(Integer i = 0; i < NUMBER_OF_TRANSACTIONS; i++) {
            Transaction__c txn = new Transaction__c();
            txn.Donor__c = donors[i].Id;
            txn.Visit__c = visits[i].Id;
            txnRecords.add(txn);
        }
        insert txnRecords;
    }

    @isTest
    private static void testBulkTxnLineItemInsert() {
        // Create a transaction
        List<Transaction__c> txnRecords = [SELECT Id FROM Transaction__c];
        List<Txn_Line_Item__c> lineItems = new List<Txn_Line_Item__c>();

        for(Transaction__c txn : txnRecords) {
            lineItems.add(new Txn_Line_Item__c(
                Transaction__c = txn.Id,
                Type__c = 'Currency',
                Quantity__c = 1,
                Unit_Cost__c = 10
            ));
            lineItems.add(new Txn_Line_Item__c(
                Transaction__c = txn.Id,
                Type__c = 'Points',
                Quantity__c = 1,
                Unit_Cost__c = 1000
            ));
        }

        Test.startTest();
        insert lineItems;
        Test.stopTest();

        // Verify that the transaction has the correct values
        txnRecords = [SELECT Id, Amount_Currency__c, Amount_Points__c FROM Transaction__c];
        
        Assert.areEqual(NUMBER_OF_TRANSACTIONS, txnRecords.size(), 'There should be ' + NUMBER_OF_TRANSACTIONS + ' transactions');
        for(Transaction__c txnRecord : txnRecords) {
            Assert.areEqual(10, txnRecord.Amount_Currency__c, 'Amount_Currency__c should be 10');
            Assert.areEqual(1000, txnRecord.Amount_Points__c, 'Amount_Points__c should be 1000');
        }
    }

    @isTest
    private static void testBulkTxnLineItemUpdate() {
        // Create a transaction
        List<Transaction__c> txnRecords = [SELECT Id FROM Transaction__c];
        List<Txn_Line_Item__c> lineItems = new List<Txn_Line_Item__c>();

        for(Transaction__c txn : txnRecords) {
            lineItems.add(new Txn_Line_Item__c(
                Transaction__c = txn.Id,
                Type__c = 'Currency',
                Quantity__c = 0,
                Unit_Cost__c = 10
            ));
            lineItems.add(new Txn_Line_Item__c(
                Transaction__c = txn.Id,
                Type__c = 'Points',
                Quantity__c = 0,
                Unit_Cost__c = 1000
            ));
        }
        insert lineItems;

        // Update the quantities to 1
        for(Txn_Line_Item__c lineItem : lineItems) {
            lineItem.Quantity__c = 1;
        }

        Test.startTest();
        update lineItems;
        Test.stopTest();

        // Verify that the transaction has the correct values
        txnRecords = [SELECT Id, Amount_Currency__c, Amount_Points__c FROM Transaction__c];
        
        Assert.areEqual(NUMBER_OF_TRANSACTIONS, txnRecords.size(), 'There should be ' + NUMBER_OF_TRANSACTIONS + ' transactions');
        for(Transaction__c txnRecord : txnRecords) {
            Assert.areEqual(10, txnRecord.Amount_Currency__c, 'Amount_Currency__c should be 10');
            Assert.areEqual(1000, txnRecord.Amount_Points__c, 'Amount_Points__c should be 1000');
        }
    }
}