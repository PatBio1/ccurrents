/**
 * Created by joshlequire1 on 3/7/23.
 */

@IsTest
public with sharing class DonorCheckinInvocableTest {

    @IsTest
    static void testBehavior() {
        Account centerAccount = TestUtil.createMiramarCenter();
        insert centerAccount;

        Datetime testDateTime = Datetime.now();
        Schedule__c testSchedule = TestUtil.createTestSchedule(centerAccount.Id, testDateTime);
        insert testSchedule;

        Appointment__c testAppointment = TestUtil.createTestAppointment(testSchedule.Id, testDateTime);
        insert testAppointment;

        Center_Donation_Type__c testCenterDonationType = TestUtil.createCenterDonationType(centerAccount.Id);
        insert testCenterDonationType;

        Account donorAccount1 = TestUtil.createDonor('123456');
        insert donorAccount1;

        Account donorAccount2 = TestUtil.createDonor('654321');
        insert donorAccount2;

        Id donor1ContactId = [SELECT PersonContactId FROM Account WHERE Id = :donorAccount1.Id][0].PersonContactId;

        Visit__c testVisit = TestUtil.createVisit(donor1ContactId, testCenterDonationType.Id, testAppointment.Id);
        insert testVisit;

        List<Donor_CheckIn__e> donorCheckInEvents = new List<Donor_CheckIn__e>{
            new Donor_CheckIn__e(Donor_Number__c = donorAccount1.DonorId__c, Timestamp__c = testDateTime.addHours(1)),
            new Donor_CheckIn__e(Donor_Number__c = donorAccount2.DonorId__c, Timestamp__c = testDateTime.addDays(-2)),
            new Donor_CheckIn__e(Donor_Number__c = 'random', Timestamp__c = testDateTime)
        };

        // Remove this and use the Eventbus.publish() call when the flow is deployed and active. This is here only for the PROD check only test to pass.
        List<List<Donor_CheckIn__e>> invocableInputList = new List<List<Donor_CheckIn__e>>();
        invocableInputList.add(donorCheckInEvents);

        Test.startTest();
        /* IF the 'Donor Checkin Handler' Flow is active, this EventBus call will work and should be used. This is on purpose - we want this test to fail if that flow is changed or deactivated, as this is a business critical process that needs to run.
        EventBus.publish(donorCheckInEvents); */
        // For PROD check only deploys to work until the flow is pushed and active.
        DonorCheckinInvocable.updateVisitStatus(invocableInputList);
        Test.stopTest();

        List<Visit__c> checkedInVisits = [SELECT Id, Status__c, Check_In__c FROM Visit__c WHERE Id = :testVisit.Id];
        Assert.areEqual(Constants.VISIT_STATUS_CHECKEDIN, checkedInVisits[0].Status__c);
        Assert.areEqual(donorCheckInEvents[0].Timestamp__c, checkedInVisits[0].Check_In__c);
    }
}