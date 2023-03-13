/**
 * Created by joshlequire1 on 3/7/23.
 */

@IsTest
public with sharing class DonorCompInvocableTest {

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

        Account donorAccount1 = TestUtil.createTestDonor('123456');
        insert donorAccount1;

        Account donorAccount2 = TestUtil.createTestDonor('654321');
        insert donorAccount2;

        Id donor1ContactId = [SELECT PersonContactId FROM Account WHERE Id = :donorAccount1.Id][0].PersonContactId;

        Visit__c testVisit = TestUtil.createVisit(donor1ContactId, testCenterDonationType.Id, testAppointment.Id);
        insert testVisit;

        List<Donor_Comp__e> donorCompEvents = new List<Donor_Comp__e>{
                new Donor_Comp__e(Donor_Number__c = donorAccount1.DonorId__c, Timestamp__c = testDateTime.addHours(1), Collection_Volume__c = 555, Collection_Number__c ='collection number', hasException__c = 0),
                new Donor_Comp__e(Donor_Number__c = donorAccount2.DonorId__c, Timestamp__c = testDateTime.addDays(-2), hasException__c = 0),
                new Donor_Comp__e(Donor_Number__c = 'random', Timestamp__c = testDateTime, hasException__c = 0)
        };

        // Remove this and use the Eventbus.publish() call when the flow is deployed and active. This is here only for the PROD check only test to pass.
        List<List<Donor_Comp__e>> invocableInputList = new List<List<Donor_Comp__e>>();
        invocableInputList.add(donorCompEvents);


        Test.startTest();
        /* IF the 'Donor Checkin Handler' Flow is active, this EventBus call will work and should be used. This is on purpose - we want this test to fail if that flow is changed or deactivated, as this is a business critical process that needs to run.
        EventBus.publish(donorCheckInEvents); */
        // For PROD check only deploys to work until the flow is pushed and active.
        DonorCompInvocable.updateVisitStatusComplete(invocableInputList);
        Test.stopTest();

        List<Visit__c> compVisits = [SELECT Id, Status__c, Donation_Complete__c, Outcome__c, Collection_Number__c, Donation_Volume__c FROM Visit__c WHERE Id = :testVisit.Id];
        Integer noMatchingDonorCount = 0;
        Integer noMatchingVisitCount = 0;
        for (ErrorLog__c er : [SELECT Id, Type__c, ShortMessage__c, Origin__c FROM ErrorLog__c WHERE Origin__c = 'DonorCompInvocable.updateVisitStatusComplete']) {
            if (er.ShortMessage__c == 'Donor Comp Event Exception: No matching donor') {
                noMatchingDonorCount++;
            } else if (er.ShortMessage__c == 'Donor Comp Event Exception: No matching visit') {
                noMatchingVisitCount++;
            }
        }

        Assert.areEqual(Constants.VISIT_STATUS_COMPLETE, compVisits[0].Status__c);
        Assert.areEqual(donorCompEvents[0].Timestamp__c, compVisits[0].Donation_Complete__c);
        Assert.areEqual(Constants.VISIT_OUTCOME_DONATION, compVisits[0].Outcome__c);
        Assert.areEqual(donorCompEvents[0].Collection_Number__c, compVisits[0].Collection_Number__c);
        Assert.areEqual(donorCompEvents[0].Collection_Volume__c, compVisits[0].Donation_Volume__c);
        Assert.areEqual(1, noMatchingVisitCount);
        Assert.areEqual(1, noMatchingDonorCount);

    }

}