@IsTest
public class DonationServiceTest {
    final static Integer AMOUNT_OF_DONORS = 200;

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
        Integer counter = 0;

        for(Contact contact : [SELECT Id, AccountId FROM Contact WHERE AccountId IN :donors]) {
            visits.add(new Visit__c(
                Appointment__c = appointments[counter].Id,
                Donor__c = contact.Id,
                Center_Donation_Type__c = testCenterDonationType.Id,
                Status__c = 'Scheduled'
            ));
        }
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

        Test.startTest();
        DonationService.createExceptionTransaction(exceptionPaymentRequest);
        Test.stopTest();

        List<Transaction__c> createdTransactions = [SELECT Id, Amount_Currency__c, (SELECT Id, Total__c, Item__c FROM Txn_Line_Items__r) FROM Transaction__c];
        Assert.areEqual(1, createdTransactions.size(), 'Amount of created transactions should be equal to 1');
        
        Assert.areEqual(targetExceptionRate.Base_Payment__c, createdTransactions[0].Amount_Currency__c, 'Amount of created transaction should be equal to base payment of exception rate');
        Assert.areEqual(1, createdTransactions[0].Txn_Line_Items__r.size(), 'Amount of line items in created transaction should be equal to 1');
        Assert.areEqual(targetExceptionRate.Base_Payment__c, createdTransactions[0].Txn_Line_Items__r[0].Total__c, 'Total of line item in created transaction should be equal to base payment of exception rate');
        Assert.areEqual(targetExceptionRate.Description__c, createdTransactions[0].Txn_Line_Items__r[0].Item__c, 'Item of line item in created transaction should be equal to exception rate description');
    }

    @IsTest 
    static void testCreateExceptionTransactions() {
        Rate__c targetExceptionRate = [SELECT Id, Base_Payment__c, Description__c FROM Rate__c WHERE Type__c = 'Exception' LIMIT 1];
        List<Visit__c> targetVisits = [SELECT Id, Donor__c FROM Visit__c];

        List<DonationService.DonationExceptionRequest> exceptionPaymentRequests = new List<DonationService.DonationExceptionRequest>();
        for(Visit__c visit : targetVisits) {
            exceptionPaymentRequests.add(new DonationService.DonationExceptionRequest(
                visit.Donor__c, visit.Id, targetExceptionRate.Id
            ));
        }

        Test.startTest();
        DonationService.createExceptionTransactions(exceptionPaymentRequests);
        Test.stopTest();

        List<Transaction__c> createdTransactions = [SELECT Id, Amount_Currency__c, (SELECT Id, Total__c, Item__c FROM Txn_Line_Items__r) FROM Transaction__c];
        Assert.areEqual(AMOUNT_OF_DONORS, createdTransactions.size(), 'Amount of created transactions should be equal to amount of donors');

        for(Transaction__c txnRecord : createdTransactions) {
            Assert.areEqual(targetExceptionRate.Base_Payment__c, txnRecord.Amount_Currency__c, 'Amount of created transaction should be equal to base payment of exception rate');
            Assert.areEqual(1, txnRecord.Txn_Line_Items__r.size(), 'Amount of line items in created transaction should be equal to 1');
            Assert.areEqual(targetExceptionRate.Base_Payment__c, txnRecord.Txn_Line_Items__r[0].Total__c, 'Total of line item in created transaction should be equal to base payment of exception rate');
            Assert.areEqual(targetExceptionRate.Description__c, txnRecord.Txn_Line_Items__r[0].Item__c, 'Item of line item in created transaction should be equal to exception rate description');
        }
    }
}