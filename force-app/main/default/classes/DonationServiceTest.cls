@IsTest
public class DonationServiceTest {
    final static Integer AMOUNT_OF_DONORS = 100; // Can't process more than 100 requests in one transaction due to callout limits

    @TestSetup
    static void createTestData() {
        Account centerAccount = TestUtil.createMiramarCenter();
        insert centerAccount;

        Center_Donation_Type__c testCenterDonationType = TestUtil.createCenterDonationType(centerAccount.Id);
        insert testCenterDonationType;

        Datetime testDateTime = Datetime.now();
        Schedule__c testSchedule = TestUtil.createTestSchedule(centerAccount.Id, testDateTime);
        insert testSchedule;

        List<Account> donors = new List<Account>();
        List<Appointment__c> appointments = new List<Appointment__c>();

        Datetime currentDatetime = testDateTime;
        for (Integer i = 0; i < AMOUNT_OF_DONORS; i++) {
            donors.add(TestUtil.createDonor(String.valueOf(i)));

            Appointment__c testAppointment = TestUtil.createTestAppointment(testSchedule.Id, currentDatetime);
            testAppointment.Capacity__c = 10;

            appointments.add(testAppointment);
            currentDatetime = testDateTime.addDays(1);
        }

        // Add one more appointment to allow shifting while rescheduling
        appointments.add(TestUtil.createTestAppointment(testSchedule.Id, currentDatetime));

        insert donors;
        insert appointments;

        List<Visit__c> visits = new List<Visit__c>();
        List<Payment_Method__c> donorPaymentMethods = new List<Payment_Method__c>();
        Integer counter = 0;

        for(Contact contact : [SELECT Id, AccountId FROM Contact WHERE AccountId IN :donors]) {
            visits.add(new Visit__c(
                Appointment__c = appointments[counter].Id,
                Donor__c = contact.Id,
                Center_Donation_Type__c = testCenterDonationType.Id,
                Status__c = 'Scheduled'
            ));

            donorPaymentMethods.add(new Payment_Method__c(
                Name = 'Test Payment Method',
                Donor__c = contact.Id,
                Account_Token__c = String.valueOf(1050 + counter),
                Account_Number__c = '4968712468235235',
                Card_Number__c = String.valueOf(1000 + (Math.random() * 8999).intValue()),
                Is_Active__c = true,
                isDefault__c = true,
                Partner_User_Id__c = contact.Id
            ));

            counter++;
        }

        insert donorPaymentMethods;
        insert visits;

        // Create Exception Rate for Center Donation
        Rate__c exceptionRate = new Rate__c(
            Base_Payment__c = 100,
            Center__c = centerAccount.Id,
            Donation_Type__c = testCenterDonationType.Donation_Type__c,
            Description__c = 'Test Exception',
            Type__c = 'Exception'
        );
        insert exceptionRate;
    }

    @IsTest 
    static void testCreateExceptionTransaction() {
        Rate__c targetExceptionRate = [SELECT Id, Base_Payment__c, Description__c FROM Rate__c WHERE Type__c = 'Exception' LIMIT 1];
        Visit__c targetVisit = [SELECT Id, Donor__c FROM Visit__c LIMIT 1];

        DonationService.DonationExceptionRequest exceptionPaymentRequest = new DonationService.DonationExceptionRequest(
            targetVisit.Donor__c, targetVisit.Id, targetExceptionRate.Id
        );

        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        DonationService.createExceptionTransaction(exceptionPaymentRequest);
        Test.stopTest();

        List<Transaction__c> createdTransactions = [SELECT Id, Amount_Currency__c, Status__c, SubType__c, (SELECT Id, Total__c, Item__c FROM Txn_Line_Items__r) FROM Transaction__c];
        Assert.areEqual(2, createdTransactions.size(), 'Amount of created transactions should be equal to 1');
        
        for(Transaction__c createdTransaction : createdTransactions) {
            Assert.areEqual('Complete', createdTransaction.Status__c, 'Status of created transaction should be equal to Complete');
            Assert.areEqual(targetExceptionRate.Base_Payment__c, createdTransaction.Amount_Currency__c, 'Amount of created transaction should be equal to base payment of exception rate');
            Assert.areEqual(1, createdTransaction.Txn_Line_Items__r.size(), 'Amount of line items in created transaction should be equal to 1');
            Assert.areEqual(targetExceptionRate.Base_Payment__c, createdTransaction.Txn_Line_Items__r[0].Total__c, 'Total of line item in created transaction should be equal to base payment of exception rate');
            Assert.areEqual(targetExceptionRate.Description__c, createdTransaction.Txn_Line_Items__r[0].Item__c, 'Item of line item in created transaction should be equal to exception rate description');
            Assert.areEqual('Exception', createdTransaction.SubType__c, 'SubType of created transaction should be equal to Exception');
        }
    }

    @IsTest 
    static void testCreateExceptionTransactions() {
        Rate__c targetExceptionRate = [SELECT Id, Base_Payment__c, Description__c, Center__c FROM Rate__c WHERE Type__c = 'Exception' LIMIT 1];
        List<Visit__c> targetVisits = [SELECT Id, Donor__c FROM Visit__c];

        List<DonationService.DonationExceptionRequest> exceptionPaymentRequests = new List<DonationService.DonationExceptionRequest>();
        for(Visit__c visit : targetVisits) {
            exceptionPaymentRequests.add(new DonationService.DonationExceptionRequest(
                visit.Donor__c, visit.Id, targetExceptionRate.Id
            ));
        }

        update new Account(
            Id = targetExceptionRate.Center__c,
            Max_Dollar_Per_Day__c = (targetExceptionRate.Base_Payment__c * targetVisits.size())
        );

        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        DonationService.createExceptionTransactions(exceptionPaymentRequests);
        Test.stopTest();

        List<Transaction__c> createdTransactions = [SELECT Id, Amount_Currency__c, Status__c, SubType__c, (SELECT Id, Total__c, Item__c FROM Txn_Line_Items__r) FROM Transaction__c];
        Assert.areEqual(AMOUNT_OF_DONORS * 2, createdTransactions.size(), 'Amount of created transactions should be equal to amount of donors');

        for(Transaction__c txnRecord : createdTransactions) {
            Assert.areEqual('Complete', txnRecord.Status__c, 'Status of created transaction should be equal to Complete');
            Assert.areEqual('Exception', txnRecord.SubType__c, 'SubType of created transaction should be equal to Exception');
            Assert.areEqual(targetExceptionRate.Base_Payment__c, txnRecord.Amount_Currency__c, 'Amount of created transaction should be equal to base payment of exception rate');
            Assert.areEqual(1, txnRecord.Txn_Line_Items__r.size(), 'Amount of line items in created transaction should be equal to 1');
            Assert.areEqual(targetExceptionRate.Base_Payment__c, txnRecord.Txn_Line_Items__r[0].Total__c, 'Total of line item in created transaction should be equal to base payment of exception rate');
            Assert.isTrue(
                txnRecord.Txn_Line_Items__r[0].Item__c == targetExceptionRate.Description__c || txnRecord.Txn_Line_Items__r[0].Item__c == 'Debit Payment',
                'Item of line item in created transaction should be equal to exception rate description'
            );
        }
    }

    @IsTest 
    static void testCreateExceptionTransactionsWithLimits() {
        Rate__c targetExceptionRate = [SELECT Id, Base_Payment__c, Description__c, Center__c FROM Rate__c WHERE Type__c = 'Exception' LIMIT 1];
        List<Visit__c> targetVisits = [SELECT Id, Donor__c FROM Visit__c];

        List<DonationService.DonationExceptionRequest> exceptionPaymentRequests = new List<DonationService.DonationExceptionRequest>();
        Decimal totalExceptionPaymentAmount = targetExceptionRate.Base_Payment__c * targetVisits.size();

        for(Visit__c visit : targetVisits) {
            exceptionPaymentRequests.add(new DonationService.DonationExceptionRequest(
                visit.Donor__c, visit.Id, targetExceptionRate.Id
            ));
        }

        Boolean isExceptionThrown = false;
        update new Account(
            Id = targetExceptionRate.Center__c,
            Max_Dollar_Per_Day__c = totalExceptionPaymentAmount - 1
        );

        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        try {
            DonationService.createExceptionTransactions(exceptionPaymentRequests);
        } catch(Exception e) {
            isExceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(isExceptionThrown, 'Exception should be thrown when total exception payment amount exceeds center limit');
        
        List<Transaction__c> createdTransactions = [SELECT Id, Amount_Currency__c, (SELECT Id, Total__c, Item__c FROM Txn_Line_Items__r) FROM Transaction__c];
        Assert.areEqual(0, createdTransactions.size(), 'No Transactions should have been made when limit is exceeded');
    }
}