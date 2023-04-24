@IsTest 
public class TransactionSelectorTest {
    static Integer AMOUNT_OF_TEST_TRANSACTIONS = 5;

    @TestSetup
    static void createTestData() {
        System.runAs(TestUtil.createAdminUser()) {
            Account centerAccount = TestUtil.createMiramarCenter();
            insert centerAccount;

            Center_Donation_Type__c testCenterDonationType = TestUtil.createCenterDonationType(centerAccount.Id);
            insert testCenterDonationType;

            Account donorAccount = TestUtil.createDonor('123456');
            insert donorAccount;

            Id donorContactId = [SELECT PersonContactId FROM Account WHERE Id = :donorAccount.Id LIMIT 1].PersonContactId;

            Schedule__c testSchedule = TestUtil.createTestSchedule(centerAccount.Id, Datetime.now());
            insert testSchedule;

            List<Appointment__c> testAppointments = new List<Appointment__c>();
            for (Integer i = 0; i < AMOUNT_OF_TEST_TRANSACTIONS; i++) {
                testAppointments.add(TestUtil.createTestAppointment(testSchedule.Id, Datetime.now()));
            }
            insert testAppointments;

            List<Visit__c> testVisits = new List<Visit__c>();
            for (Appointment__c appointmentRecord : testAppointments) {
                testVisits.add(new Visit__c(
                    Appointment__c = appointmentRecord.Id,
                    Center_Donation_Type__c = testCenterDonationType.Id,
                    Donor__c = donorContactId,
                    Status__c = 'Complete',
                    Outcome__c = 'Donation'
                ));
            }
            insert testVisits;

            List<Transaction__c> testTransactions = new List<Transaction__c>();
            for (Integer i = 0; i < AMOUNT_OF_TEST_TRANSACTIONS; i++) {
                testTransactions.add(new Transaction__c(
                    Donor__c = donorContactId,
                    Visit__c = testVisits[i].Id,
                    Type__c = 'Credit'
                ));
            }
            insert testTransactions;

            List<Txn_Line_Item__c> testLineItems = new List<Txn_Line_Item__c>();
            for(Transaction__c transactionRecord : testTransactions) {
                testLineItems.add(new Txn_Line_Item__c(
                    Item__c	= 'Donation Points',
                    Quantity__c = 1,
                    Type__c = 'Points',
                    Unit_Cost__c = 100,
                    Transaction__c = transactionRecord.Id
                ));

                testLineItems.add(new Txn_Line_Item__c(
                    Item__c	= 'Donation Payment',
                    Quantity__c = 1,
                    Type__c = 'Currency',
                    Unit_Cost__c = 10,
                    Transaction__c = transactionRecord.Id
                ));
            }
            insert testLineItems;
        }
    }

    @IsTest
    static void testGetUserTransactions() {
        List<TransactionSelector.DonorTransaction> testTransactions;

        Test.startTest();
        System.runAs(TestUtil.createExperienceUserFromContactId([SELECT PersonContactId FROM Account WHERE RecordType.DeveloperName = 'Donor' LIMIT 1]?.PersonContactId)) { 
            testTransactions = TransactionSelector.getUserTransactions();
        }
        Test.stopTest();

        Assert.areEqual(AMOUNT_OF_TEST_TRANSACTIONS, testTransactions.size(), 'The amount of transactions returned does not match the amount of transactions created.');
        for(TransactionSelector.DonorTransaction transactionRecord : testTransactions) {
            Assert.areEqual(10, transactionRecord.currencyTotal, 'The currency total of the transaction does not match the expected value (10).');
            Assert.areEqual(100, transactionRecord.pointTotal, 'The points total of the transaction does not match the expected value (100).');
            Assert.areEqual(2, transactionRecord.transactionLineItems.size(), 'The amount of line items in the transaction does not match the expected value (2).');
        }
    }
}