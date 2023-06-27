@IsTest 
public class TransactionSelectorTest {
    static Integer AMOUNT_OF_TEST_TRANSACTIONS = 5;
    static String TEST_DONOR_ID = '123456';
    static Decimal TEST_AMOUNT_CURRENCY = 10;
    static Decimal TEST_AMOUNT_POINTS = 100;

    @TestSetup
    static void createTestData() {
        System.runAs(TestUtil.createAdminUser()) {
            Account centerAccount = TestUtil.createMiramarCenter();
            insert centerAccount;

            Center_Donation_Type__c testCenterDonationType = TestUtil.createCenterDonationType(centerAccount.Id);
            insert testCenterDonationType;

            Account donorAccount = TestUtil.createDonor(TEST_DONOR_ID);
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
                    Type__c = 'Credit',
                    Status__c = 'Complete'
                ));

                testTransactions.add(new Transaction__c(
                    Donor__c = donorContactId,
                    Visit__c = testVisits[i].Id,
                    Type__c = 'Debit',
                    Status__c = 'Complete'
                ));
            }
            insert testTransactions;

            List<Txn_Line_Item__c> testLineItems = new List<Txn_Line_Item__c>();
            for(Transaction__c transactionRecord : testTransactions) {
                if (transactionRecord.Type__c == 'Credit') {
                    testLineItems.add(new Txn_Line_Item__c(
                        Item__c	= 'Donation Points',
                        Quantity__c = 1,
                        Type__c = 'Points',
                        Unit_Cost__c = TEST_AMOUNT_POINTS,
                        Transaction__c = transactionRecord.Id
                    ));
                }

                testLineItems.add(new Txn_Line_Item__c(
                    Item__c	= 'Donation Payment',
                    Quantity__c = 1,
                    Type__c = 'Currency',
                    Unit_Cost__c = TEST_AMOUNT_CURRENCY,
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
            Assert.areEqual(TEST_AMOUNT_CURRENCY, transactionRecord.currencyTotal, 'The currency total of the transaction does not match the expected value (10).');
            Assert.areEqual(TEST_AMOUNT_POINTS, transactionRecord.pointTotal, 'The points total of the transaction does not match the expected value (100).');
            Assert.areEqual(2, transactionRecord.transactionLineItems.size(), 'The amount of line items in the transaction does not match the expected value (2).');
        }
    }

    @IsTest 
    static void testGetUserTransactionsWithPointRedemption() {
        Contact testDonorContact = [SELECT Id FROM Contact WHERE Account.DonorId__c = :TEST_DONOR_ID LIMIT 1];
        Decimal redeemedPoints = 1000;
        Decimal redeemedCurrency = 10;

        List<Transaction__c> pointRedemptionTransactions = new List<Transaction__c> {
            new Transaction__c(
                Donor__c = testDonorContact.Id,
                Type__c = 'Debit',
                SubType__c = 'Point Redemption',
                Status__c = 'Complete'
            ),
            new Transaction__c(
                Donor__c = testDonorContact.Id,
                Type__c = 'Credit',
                SubType__c = 'Point Redemption',
                Status__c = 'Complete'
            )
        };
        insert pointRedemptionTransactions;

        List<Txn_Line_Item__c> pointRedemptionLineItems = new List<Txn_Line_Item__c> {
            new Txn_Line_Item__c(
                Item__c = 'Redeemed Points',
                Quantity__c = 1,
                Type__c = 'Points',
                Unit_Cost__c = redeemedPoints,
                Transaction__c = pointRedemptionTransactions[0].Id
            ),
            new Txn_Line_Item__c(
                Item__c = 'Redeemed Currency',
                Quantity__c = 1,
                Type__c = 'Currency',
                Unit_Cost__c = redeemedCurrency,
                Transaction__c = pointRedemptionTransactions[0].Id
            ),
            new Txn_Line_Item__c(
                Item__c = 'Redeemed Points',
                Quantity__c = 1,
                Type__c = 'Points',
                Unit_Cost__c = redeemedPoints,
                Transaction__c = pointRedemptionTransactions[1].Id
            ),
            new Txn_Line_Item__c(
                Item__c = 'Redeemed Currency',
                Quantity__c = 1,
                Type__c = 'Currency',
                Unit_Cost__c = redeemedCurrency,
                Transaction__c = pointRedemptionTransactions[1].Id
            )
        };
        insert pointRedemptionLineItems;

        List<TransactionSelector.DonorTransaction> testTransactions;
        Set<Id> testPointRedemptionIds = new Set<Id> {
            pointRedemptionTransactions[0].Id,
            pointRedemptionTransactions[1].Id
        };
        Boolean wasPointRedemptionTransactionFound = false;

        Test.startTest();
        System.runAs(TestUtil.createExperienceUserFromContactId([SELECT PersonContactId FROM Account WHERE RecordType.DeveloperName = 'Donor' LIMIT 1]?.PersonContactId)) { 
            testTransactions = TransactionSelector.getUserTransactions();
        }
        Test.stopTest();

        Assert.areEqual(AMOUNT_OF_TEST_TRANSACTIONS + 1, testTransactions.size(), 'The amount of transactions returned does not match the amount of transactions created.');
        for(TransactionSelector.DonorTransaction transactionRecord : testTransactions) {
            if (testPointRedemptionIds.contains(transactionRecord.transactionId)) {
                Assert.areEqual(redeemedCurrency, transactionRecord.currencyTotal, 'The currency total of the transaction does not match the expected value.');
                Assert.areEqual(redeemedPoints, transactionRecord.pointTotal, 'The points total of the transaction does not match the expected value.');
                Assert.areEqual(2, transactionRecord.transactionLineItems.size(), 'The amount of line items in the transaction does not match the expected value.');

                wasPointRedemptionTransactionFound = true;
                continue;
            }

            Assert.areEqual(TEST_AMOUNT_CURRENCY, transactionRecord.currencyTotal, 'The currency total of the transaction does not match the expected value.');
            Assert.areEqual(TEST_AMOUNT_POINTS, transactionRecord.pointTotal, 'The points total of the transaction does not match the expected value.');
            Assert.areEqual(2, transactionRecord.transactionLineItems.size(), 'The amount of line items in the transaction does not match the expected value.');
        }

        Assert.isTrue(wasPointRedemptionTransactionFound, 'The point redemption transaction was not found in the list of transactions.');
    }
}