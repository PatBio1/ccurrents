@IsTest
public class ExceptionPaymentControllerTest {
    final static Integer AMOUNT_OF_DONORS = 10;

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

        // Create Exception Rates for Center Donation
        List<Rate__c> rates = new List<Rate__c>();
        rates.add(new Rate__c(
            Base_Payment__c = 50,
            Center__c = centerAccount.Id,
            Donation_Type__c = testCenterDonationType.Donation_Type__c,
            Description__c = 'Test Exception Rate 1',
            Type__c = 'Exception'
        ));
        rates.add(new Rate__c(
            Base_Payment__c = 150,
            Center__c = centerAccount.Id,
            Donation_Type__c = testCenterDonationType.Donation_Type__c,
            Description__c = 'Test Exception Rate 2',
            Type__c = 'Exception'
        ));
        rates.add(new Rate__c(
            Base_Payment__c = 100,
            Center__c = centerAccount.Id,
            Donation_Type__c = testCenterDonationType.Donation_Type__c,
            Description__c = 'Test Exception Rate 3',
            Type__c = 'Exception'
        ));
        rates.add(new Rate__c(
            Base_Payment__c = 200,
            Center__c = centerAccount.Id,
            Donation_Type__c = testCenterDonationType.Donation_Type__c,
            Description__c = 'Test Exception Rate 4',
            Type__c = 'Exception'
        ));
        insert rates;
    }

    @IsTest 
    static void testCreateExceptionPayment() {
        Rate__c targetExceptionRate = [SELECT Id, Base_Payment__c, Description__c FROM Rate__c WHERE Type__c = 'Exception' LIMIT 1];
        Visit__c targetVisit = [SELECT Id, Donor__c FROM Visit__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        ExceptionPaymentController.createExceptionPayment(targetVisit.Donor__c, targetVisit.Id, targetExceptionRate.Id);
        Test.stopTest();

        List<Transaction__c> createdTransactions = [SELECT Id, Amount_Currency__c, Type__c, SubType__c, Status__c, (SELECT Id, Total__c, Item__c FROM Txn_Line_Items__r) FROM Transaction__c];
        Assert.areEqual(2, createdTransactions.size(), 'Amount of created transactions should be equal to 2');
        
        Set<String> expectedTypes = new Set<String> { 'Credit', 'Debit' };
        for(Transaction__c createdTransaction : createdTransactions) {
            Assert.areEqual(targetExceptionRate.Base_Payment__c, createdTransaction.Amount_Currency__c, 'Amount of created transaction should be equal to base payment of exception rate');
            Assert.areEqual(1, createdTransaction.Txn_Line_Items__r.size(), 'Amount of line items in created transaction should be equal to 1');
            Assert.areEqual(targetExceptionRate.Base_Payment__c, createdTransaction.Txn_Line_Items__r[0].Total__c, 'Total of line item in created transaction should be equal to base payment of exception rate');
            Assert.areEqual(targetExceptionRate.Description__c, createdTransaction.Txn_Line_Items__r[0].Item__c, 'Item of line item in created transaction should be equal to exception rate description');
            Assert.areEqual('Exception', createdTransaction.SubType__c, 'The transactions should have been created with a subtype of exception');
            Assert.areEqual('Complete', createdTransaction.Status__c, 'The transactions should have a status of complete');

            expectedTypes.remove(createdTransaction.Type__c);
        }

        Assert.isTrue(expectedTypes.isEmpty(), 'All expected types should have been found in created transactions');
    }

    @IsTest 
    static void testGetBaseVisitExceptionPaymentInfo() {
        Visit__c targetVisit = [
            SELECT Id, Appointment_Datetime__c, Donor__c, Donor__r.Name, Center_Donation_Type__r.Center__r.Name, Center_Donation_Type__r.Center__c, Center_Donation_Type__r.Donation_Type__c, Age_in_Days__c 
            FROM Visit__c 
            LIMIT 1
        ];

        Map<Id, Rate__c> exceptionRates = new Map<Id, Rate__c>([
            SELECT Id, Base_Payment__c, Description__c 
            FROM Rate__c 
            WHERE Type__c = 'Exception' AND 
                Center__c = :targetVisit.Center_Donation_Type__r.Center__c AND 
                Donation_Type__c = :targetVisit.Center_Donation_Type__r.Donation_Type__c
        ]);

        Test.startTest();
        ExceptionPaymentController.VisitExceptionPaymentInfo exceptionPaymentInfo = ExceptionPaymentController.getBaseVisitExceptionPaymentInfo(targetVisit.Id);
        Test.stopTest();

        Assert.isNotNull(exceptionPaymentInfo, 'Exception payment info should not be null');
        Assert.areEqual(targetVisit.Id, exceptionPaymentInfo.visitId, 'Visit id in exception payment info should be equal to target visit id');
        Assert.areEqual(targetVisit.Donor__c, exceptionPaymentInfo.visitDonorId, 'Donor id in exception payment info should be equal to target visit donor id');
        Assert.areEqual(targetVisit.Donor__r.Name, exceptionPaymentInfo.visitDonorName, 'Donor name in exception payment info should be equal to target visit donor name');
        Assert.areEqual(targetVisit.Age_in_Days__c, exceptionPaymentInfo.visitAge, 'Datetime in exception payment info should be equal to target visit datetime');
        Assert.areEqual(targetVisit.Center_Donation_Type__r.Center__r.Name, exceptionPaymentInfo.visitCenterName, 'Center name in exception payment info should be equal to target visit center name');

        Assert.areEqual(exceptionRates.size(), exceptionPaymentInfo.availableExceptionPaymentTypes.size(), 'Amount of exception rates in exception payment info should be equal to amount of exception rates for target visit');
        for(ExceptionPaymentController.ExceptionPaymentType exceptionPaymentType : exceptionPaymentInfo.availableExceptionPaymentTypes) {
            Assert.isNotNull(exceptionRates.get(exceptionPaymentType.id), 'Exception payment type id should be equal to exception rate id');
            Assert.areEqual(exceptionRates.get(exceptionPaymentType.id).Description__c, exceptionPaymentType.description, 'Exception payment type description should be equal to exception rate description');
            Assert.areEqual(exceptionRates.get(exceptionPaymentType.id).Base_Payment__c, exceptionPaymentType.amount, 'Exception payment type amount should be equal to exception rate base payment');
        }
    }

    @IsTest
    static void testExceptionPaymentExceptionHandling() {
        Rate__c targetExceptionRate = [SELECT Id, Base_Payment__c, Description__c, Center__c, Center__r.Name FROM Rate__c WHERE Type__c = 'Exception' LIMIT 1];
        Visit__c targetVisit = [SELECT Id, Donor__c FROM Visit__c LIMIT 1];

        Boolean wasExceptionThrown = false;
        String exceptionMessage;

        // Update Center Limit to 1 lower than rate payment to force exception
        Account centerAccount = new Account(
            Id = targetExceptionRate.Center__c,
            Individual_Exception_Limit__c = targetExceptionRate.Base_Payment__c - 1
        );
        update centerAccount;

        Test.startTest();
        try {
            ExceptionPaymentController.createExceptionPayment(targetVisit.Donor__c, targetVisit.Id, targetExceptionRate.Id);
        } catch(AuraHandledException e) {
            wasExceptionThrown = true;
            exceptionMessage = e.getMessage();
        }
        Test.stopTest();

        Assert.isTrue(wasExceptionThrown, 'Exception should have been thrown');
        Assert.areEqual(
            String.format(Constants.CENTER_INDIVIDUAL_EXCEPTION_LIMIT_ERROR, new List<object> { targetExceptionRate.Center__r.Name }), 
            exceptionMessage, 
            'Exception message should be equal to expected exception message'
        );
    }
}