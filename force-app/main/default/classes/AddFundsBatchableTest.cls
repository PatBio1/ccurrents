@IsTest
public without sharing class AddFundsBatchableTest {

    static final Decimal RETRY_MULTIPLIER = 1.4;
    static final Decimal BASE_RETRY_INTERVAL = 600;

    @TestSetup
    static void createTestData() {
        List<Account> testDonors = new List<Account> {
            TestUtil.createDonor('123-123'),
            TestUtil.createDonor('456-456'),
            TestUtil.createDonor('789-789')
        };
        insert testDonors;

        Account testCenter = Testutil.createMiramarCenter();
        insert testCenter;

        Schedule__c testSchedule = TestUtil.createTestSchedule(testCenter.Id, Datetime.now());
        insert testSchedule;

        Appointment__c testAppointment = TestUtil.createTestAppointment(testSchedule.Id, Datetime.now());
        insert testAppointment;

        Center_Donation_Type__c testCenterDonationType = TestUtil.createCenterDonationType(testCenter.Id);
        insert testCenterDonationType;

        List<Visit__c> testVisits = new List<Visit__c>();
        List<Payment_Method__c> donorPaymentMethods = new List<Payment_Method__c>();

        for(Contact testDonorContact : [SELECT Id FROM Contact WHERE AccountId IN :testDonors]) {
            testVisits.add(new Visit__c(
                Donor__c = testDonorContact.Id,
                Appointment__c = testAppointment.Id,
                Center_Donation_Type__c = testCenterDonationType.Id,
                Status__c = 'Complete',
                Outcome__c = 'Donation'
            ));

            donorPaymentMethods.add(new Payment_Method__c(
                Name = 'Test Payment Method',
                Donor__c = testDonorContact.Id,
                Account_Token__c = '1050',
                Account_Number__c = '4968712468235235',
                Card_Number__c = '7890',
                Is_Active__c = true,
                isDefault__c = true
            ));
        }

        insert testVisits;
        insert donorPaymentMethods;
    }

    @IsTest
    static void testSuccessfulAddFundsRun() {
        String targetTransactionSubType = 'Donation Payment';

        List<Contact> testDonors = [SELECT Id, (SELECT Id FROM Visits__r) FROM Contact WHERE Account.DonorId__c != null];
        List<DonorCompInvocable.AddFundsRequest> addFundsRequests = new List<DonorCompInvocable.AddFundsRequest>();
        Integer index = 0;

        for(Contact testDonor : testDonors) {
            DonorCompInvocable.AddFundsRequest newAddFundsRequest = new DonorCompInvocable.AddFundsRequest(testDonor.Id, testDonor.Visits__r[0].Id, '001000000000001', targetTransactionSubType);
            newAddFundsRequest.comments = new List<String> { 'Test Comment ' + index };
            newAddFundsRequest.addLineItem('Test Line Item 1', 'Currency', 100);

            addFundsRequests.add(newAddFundsRequest);
            index++;
        }

        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        Database.executeBatch(new AddFundsBatchable(addFundsRequests), 100);
        Test.stopTest();

        List<Transaction__c> createdDebitTransactions = [
            SELECT Id, Amount_Currency__c, Status__c, SubType__c, (SELECT Id FROM Txn_Line_Items__r)
            FROM Transaction__c
            WHERE Type__c = 'Debit' AND 
                Donor__c IN :testDonors
        ];

        Assert.areEqual(testDonors.size(), createdDebitTransactions.size(), 'There should be one debit transaction created for each donor');
        for(Transaction__c createdDebitTransaction : createdDebitTransactions) {
            Assert.areEqual(100.00, createdDebitTransaction.Amount_Currency__c, 'The debit transaction should have the correct amount');
            Assert.areEqual(1, createdDebitTransaction.Txn_Line_Items__r.size(), 'The debit transaction should have one line item');
            Assert.areEqual('Complete', createdDebitTransaction.Status__c, 'The debit transaction should have a status of Complete');
            Assert.areEqual(targetTransactionSubType, createdDebitTransaction.SubType__c, 'The debit transaction should have the correct sub type');
        }
    }

    @IsTest
    static void testAddFundsRunWithError() {
        String targetTransactionSubType = 'Donation Payment';

        List<Contact> testDonors = [SELECT Id, (SELECT Id FROM Visits__r) FROM Contact WHERE Account.DonorId__c != null];
        List<DonorCompInvocable.AddFundsRequest> addFundsRequests = new List<DonorCompInvocable.AddFundsRequest>();
        Integer index = 0;

        for(Contact testDonor : testDonors) {
            DonorCompInvocable.AddFundsRequest newAddFundsRequest = new DonorCompInvocable.AddFundsRequest(testDonor.Id, testDonor.Visits__r[0].Id, '001000000000001', targetTransactionSubType);
            newAddFundsRequest.comments = new List<String> { 'Test Comment ' + index };
            newAddFundsRequest.addLineItem('Test Line Item 1', 'Currency', 100);

            addFundsRequests.add(newAddFundsRequest);
            index++;
        }

        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock(true));
        TestUtil.throwException = true; // OnbePaymentService requires this

        Test.startTest();
        Database.executeBatch(new AddFundsBatchable(addFundsRequests), 100);
        Test.stopTest();

        List<Transaction__c> createdDebitTransactions = [
            SELECT Id, Amount_Currency__c, Status__c, SubType__c, Retry_Count__c, Retry_Next__c, (SELECT Id FROM Txn_Line_Items__r), (SELECT Id FROM Transaction_Logs__r)
            FROM Transaction__c
            WHERE Type__c = 'Debit' AND 
                Donor__c IN :testDonors
        ];

        Assert.areEqual(testDonors.size(), createdDebitTransactions.size(), 'There should be one debit transaction created for each donor');
        Integer expectedRetryCount = 0;
        Datetime expectedRetryNext = System.now().addSeconds((Integer)(BASE_RETRY_INTERVAL * Math.pow((Double)RETRY_MULTIPLIER, (Double)expectedRetryCount)));

        for(Transaction__c createdDebitTransaction : createdDebitTransactions) {
            Assert.areEqual(100.00, createdDebitTransaction.Amount_Currency__c, 'The debit transaction should have the correct amount');
            Assert.areEqual(1, createdDebitTransaction.Txn_Line_Items__r.size(), 'The debit transaction should have one line item');
            Assert.areEqual('Error', createdDebitTransaction.Status__c, 'The debit transaction should have a status of Error');
            Assert.areEqual(targetTransactionSubType, createdDebitTransaction.SubType__c, 'The debit transaction should have the correct sub type');
            Assert.areEqual(1, createdDebitTransaction.Transaction_Logs__r.size(), 'The debit transaction should have one transaction log detailing the error');
            Assert.areEqual(expectedRetryCount, createdDebitTransaction.Retry_Count__c, 'The debit transaction should have a retry count of 1');

            // The time is bound to be different by a couple of milliseconds, so allow for a small difference
            Decimal difference = createdDebitTransaction.Retry_Next__c.getTime() - expectedRetryNext.getTime();
            Assert.isTrue(difference < 100, 'The Retry Next field should have been set using BASE_RETRY * BASE_RETRY ^ Retry Count');
        }
    }

    @IsTest
    static void testSuccessfulAddFundsRetry() {
        List<Contact> testDonors = [SELECT Id, (SELECT Id FROM Visits__r) FROM Contact WHERE Account.DonorId__c != null];
        List<Transaction__c> mockedErrorTransactions = new List<Transaction__c>();

        for(Contact testDonor : testDonors) {
            Transaction__c newTransaction = new Transaction__c(
                Donor__c = testDonor.Id,
                Visit__c = testDonor.Visits__r[0].Id,
                Type__c = 'Debit',
                Status__c = 'Error',
                Amount_Currency__c = 100.00,
                Retry_Count__c = 0
            );

            mockedErrorTransactions.add(newTransaction);
        }
        insert mockedErrorTransactions;

        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        Database.executeBatch(new AddFundsBatchable());
        Test.stopTest();

        mockedErrorTransactions = [
            SELECT Id, Status__c, Retry_Count__c, Retry_Next__c, (SELECT Id FROM Transaction_Logs__r)
            FROM Transaction__c
            WHERE Id IN :mockedErrorTransactions
        ];

        Assert.areEqual(testDonors.size(), mockedErrorTransactions.size(), 'There should be one debit transaction created for each donor');
        for(Transaction__c mockErrorTransaction : mockedErrorTransactions) {
            Assert.areEqual('Complete', mockErrorTransaction.Status__c, 'The debit transaction should have a status of Complete after the retry');
            Assert.areEqual(0, mockErrorTransaction.Transaction_Logs__r.size(), 'No additional logs should have been created');
            Assert.areEqual(1, mockErrorTransaction.Retry_Count__c, 'The retry count should be incremented');
            Assert.isNull(mockErrorTransaction.Retry_Next__c, 'The retry next date should be null');
        }
    }

    @IsTest
    static void testSuccessfulSchedule() {
        System.schedule('Test Add Funds Run', '20 30 8 10 2 ?', new AddFundsBatchable());
    }

    @IsTest
    static void testRetryRun() {
        Map<Id, Transaction__c> donorIdToMockedTransaction = new Map<Id, Transaction__c>();
        Map<Id, List<Txn_Line_Item__c>> donorIdToTxnLineItems = new Map<Id, List<Txn_Line_Item__c>>();

        for(Contact testDonor : [SELECT Id, (SELECT Id FROM Visits__r) FROM Contact WHERE Account.DonorId__c != null]) {
            Transaction__c newTransaction = new Transaction__c(
                Donor__c = testDonor.Id,
                Visit__c = testDonor.Visits__r[0].Id,
                Type__c = 'Debit',
                Status__c = 'Error',
                Amount_Currency__c = 100.00,
                Retry_Count__c = 0
            );

            donorIdToMockedTransaction.put(testDonor.Id, newTransaction);
            donorIdToTxnLineItems.put(testDonor.Id, new List<Txn_Line_Item__c> {
                new Txn_Line_Item__c(
                    Item__c = 'Test Line Item 1',
                    Type__c = 'Currency',
                    Unit_Cost__c = 100,
                    Quantity__c = 1
                )
            });
        }

        insert donorIdToMockedTransaction.values();

        List<Txn_Line_Item__c> allTxnLineItems = new List<Txn_Line_Item__c>();
        for(Id donorId : donorIdToTxnLineItems.keySet()) {
            for(Txn_Line_Item__c txnLineItem : donorIdToTxnLineItems.get(donorId)) {
                txnLineItem.Transaction__c = donorIdToMockedTransaction.get(donorId).Id;
            }

            allTxnLineItems.addAll(donorIdToTxnLineItems.get(donorId));
        }

        insert allTxnLineItems;

        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock(true));
        TestUtil.throwException = true; // OnbePaymentService requires this

        Test.startTest();
        Database.executeBatch(new AddFundsBatchable(), 100);
        Test.stopTest();

        List<Transaction__c> updatedTransactionRecords = [
            SELECT Id, Status__c, Retry_Count__c, Retry_Next__c, (SELECT Id FROM Transaction_Logs__r)
            FROM Transaction__c
            WHERE Id IN :donorIdToMockedTransaction.values()
        ];

        Assert.areEqual(donorIdToMockedTransaction.size(), updatedTransactionRecords.size(), 'There should be one debit transaction created for each donor');
        Integer expectedRetryCount = 1;
        Datetime expectedRetryNext = System.now().addSeconds((Integer)(BASE_RETRY_INTERVAL * Math.pow((Double)RETRY_MULTIPLIER, (Double)expectedRetryCount)));

        for(Transaction__c updatedTransactionRecord : updatedTransactionRecords) {
            Assert.areEqual('Error', updatedTransactionRecord.Status__c, 'The debit transaction should have a status of Error after the retry');
            Assert.areEqual(1, updatedTransactionRecord.Transaction_Logs__r.size(), 'The debit transaction should have one transaction log detailing the error');
            Assert.areEqual(expectedRetryCount, updatedTransactionRecord.Retry_Count__c, 'The debit transaction should have a retry count of 1');

            // The time is bound to be different by a couple of milliseconds, so allow for a small difference
            Decimal difference = updatedTransactionRecord.Retry_Next__c.getTime() - expectedRetryNext.getTime();
            Assert.isTrue(difference < 100, 'The Retry Next field should have been set using BASE_RETRY * BASE_RETRY ^ Retry Count');
        }
    }
}