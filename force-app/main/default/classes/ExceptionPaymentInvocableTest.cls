@isTest
public with sharing class ExceptionPaymentInvocableTest {

    @isTest
    static void testInvoke() {
        User experienceUser = TestUtil.createExperienceUser();
        Decimal testAmount = 100;

        System.runAs(TestUtil.createAdminUser()) {
            Account center = TestUtil.createMiramarCenter();
            insert center;

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = Date.newInstance(2023, 1, 10).addDays(-10),
                End_Date__c = Date.newInstance(2023, 1, 10).addDays(30)
            );
            insert schedule;

            Appointment__c appointment = new Appointment__c();
            appointment.Schedule__c = schedule.Id;
            appointment.Datetime__c = DateTime.newInstance(2023, 1, 10, 10, 0, 0);
            appointment.Duration__c = 10;
            appointment.Capacity__c = 5;
            insert appointment;

            Donation_Type__c donationType = new Donation_Type__c();
            insert donationType;

            Center_Donation_Type__c centerDonationType = new Center_Donation_Type__c();
            centerDonationType.Center__c = center.Id;
            centerDonationType.Donation_Type__c = donationType.Id;
            centerDonationType.isActive__c = true;
            insert centerDonationType;

            Visit__c visit = new Visit__c();
            visit.Appointment__c = appointment.Id;
            visit.Donor__c = experienceUser.ContactId;
            visit.Status__c = 'Scheduled';
            visit.Center_Donation_Type__c = centerDonationType.Id;
            insert visit;

            Payment_Method__c paymentMethod = new Payment_Method__c();
            paymentMethod.Name = 'Test Payment Method';
            paymentMethod.Account_Number__c = '1234567890';
            paymentMethod.Account_Token__c = '1234';
            paymentMethod.Donor__c = experienceUser.ContactId;
            paymentMethod.Is_Active__c = true;
            paymentMethod.isDefault__c = true;
            insert paymentMethod;

            ExceptionPaymentInvocable.ExceptionPaymentRequest exceptionPaymentRequest = new ExceptionPaymentInvocable.ExceptionPaymentRequest();
            exceptionPaymentRequest.donorId = experienceUser.ContactId;
            exceptionPaymentRequest.visitId = visit.Id;
            exceptionPaymentRequest.amount = testAmount;
            exceptionPaymentRequest.reason = 'reason';

            Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

            Test.startTest();
            List<ExceptionPaymentInvocable.ExceptionPaymentResponse> exceptionPaymentResponses = ExceptionPaymentInvocable.invoke(new List<ExceptionPaymentInvocable.ExceptionPaymentRequest>{exceptionPaymentRequest});
            Test.stopTest();

            Assert.areEqual(1, exceptionPaymentResponses.size(), 'Only one response should be returned');
            Assert.areEqual(experienceUser.ContactId, exceptionPaymentResponses[0].donorId, 'Donor ID should be returned');
            Assert.areEqual(visit.Id, exceptionPaymentResponses[0].visitId, 'Visit ID should be returned');
            Assert.areEqual(testAmount, exceptionPaymentResponses[0].amount, 'Amount should be returned');
            Assert.areEqual('reason', exceptionPaymentResponses[0].reason, 'Reason should be returned');

            List<Transaction__c> createdTransactions = [SELECT Id, Amount_Currency__c, Status__c, SubType__c FROM Transaction__c WHERE Donor__c = :experienceUser.ContactId AND Visit__c = :visit.Id];
            Assert.areEqual(2, createdTransactions.size(), 'A debit and credit transaction record should have been created');

            for(Transaction__c createdTransaction : createdTransactions) {
                Assert.areEqual('Complete', createdTransaction.Status__c, 'Transaction should be complete');
                Assert.areEqual('Exception', createdTransaction.SubType__c, 'Transaction should be an exception');
                Assert.areEqual(testAmount, createdTransaction.Amount_Currency__c, 'Transaction amount should be the same as the request amount');
            }
        }
    }
}