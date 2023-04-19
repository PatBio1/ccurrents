/**
 * Created by joshlequire1 on 3/7/23.
 */

@IsTest
public with sharing class DonorCompInvocableTest {

    static Integer TEST_DONATION_THRESHOLD = 5;

    @TestSetup
    static void makeData() {
        Account centerAccount = TestUtil.createMiramarCenter();
        insert centerAccount;

        Schedule__c testSchedule = TestUtil.createTestSchedule(centerAccount.Id, Datetime.now());
        insert testSchedule;

        Appointment__c testAppointment = TestUtil.createTestAppointment(testSchedule.Id, Datetime.now());
        insert testAppointment;

        Center_Donation_Type__c testCenterDonationType = TestUtil.createCenterDonationType(centerAccount.Id);
        Donation_Type__c testDonationType = [SELECT Id FROM Donation_Type__c LIMIT 1];
        insert testCenterDonationType;
        
        Rate__c testRateRecord = new Rate__c(
            Donation_Type__c = testDonationType.Id,
            Center__c = centerAccount.Id,
            Base_Payment__c = 100,
            Type__c = 'Base'
        );
        insert testRateRecord;

        Level__c testLevel2 = new Level__c(Name = 'Level 2', Donation_Threshold__c = TEST_DONATION_THRESHOLD, Donation_Payment__c = 200, Donation_Points__c = 2000, Threshold_Points__c = 1000, Threshold_Payment__c = 100, isActive__c = true, isVisible__c = true);
        insert testLevel2;

        Level__c testLevel1 = new Level__c(Name = 'Level 1', Donation_Payment__c = 100, Donation_Points__c = 1000, Threshold_Points__c = 500, Threshold_Payment__c = 50, Next_Level__c = testLevel2.Id, isActive__c = true, isVisible__c = true);
        insert testLevel1;

        Level__c bonusLevel1 = new Level__c(Name = 'Bonus Level 1', Donation_Threshold__c = TEST_DONATION_THRESHOLD - 1, Threshold_Points__c = 333, Threshold_Payment__c = 33, isActive__c = true, isVisible__c = false);
        insert bonusLevel1;

        Account donorAccount1 = TestUtil.createTestDonor('123456');
        donorAccount1.Loyalty_Level__pc = testLevel1.Id;
        insert donorAccount1;

        Account donorAccount2 = TestUtil.createTestDonor('654321');
        donorAccount2.Loyalty_Level__pc = testLevel1.Id;
        insert donorAccount2;
    }

    @IsTest
    static void testUpdateVisitStatusComplete() {
        List<Account> donorAccounts = [SELECT Id, DonorId__c FROM Account WHERE DonorId__c != null];
        Id appointmentId = [SELECT Id FROM Appointment__c LIMIT 1][0].Id;
        Id centerDonationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1][0].Id;
        Id donor1ContactId = [SELECT PersonContactId FROM Account WHERE Id = :donorAccounts[0].Id][0].PersonContactId;

        Visit__c testVisit = TestUtil.createVisit(donor1ContactId, centerDonationType, appointmentId);
        insert testVisit;

        List<Donor_Comp__e> donorCompEvents = new List<Donor_Comp__e>{
            new Donor_Comp__e(Donor_Number__c = donorAccounts[0].DonorId__c, Timestamp__c = Datetime.now().addHours(1), Collection_Volume__c = 555, Collection_Number__c ='collection number', hasException__c = 0),
            new Donor_Comp__e(Donor_Number__c = donorAccounts[1].DonorId__c, Timestamp__c = Datetime.now().addDays(-2), hasException__c = 0),
            new Donor_Comp__e(Donor_Number__c = 'random', Timestamp__c = Datetime.now(), hasException__c = 0)
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

        Assert.areEqual(Constants.VISIT_STATUS_COMPLETE, compVisits[0].Status__c);
        Assert.areEqual(donorCompEvents[0].Timestamp__c, compVisits[0].Donation_Complete__c);
        Assert.areEqual(Constants.VISIT_OUTCOME_DONATION, compVisits[0].Outcome__c);
        Assert.areEqual(donorCompEvents[0].Collection_Number__c, compVisits[0].Collection_Number__c);
        Assert.areEqual(donorCompEvents[0].Collection_Volume__c, compVisits[0].Donation_Volume__c);
    }

    @IsTest
    static void testHandleCreateDonationTransactions() {
        List<Account> donorAccounts = [SELECT Id, PersonContactId, DonorId__c FROM Account WHERE DonorId__c != null LIMIT 1];
        Id scheduledId = [SELECT Id FROM Schedule__c LIMIT 1]?.Id;

        List<Appointment__c> testAppointments = new List<Appointment__c>();
        Datetime currentDatetime = Datetime.now().addDays(-14 * TEST_DONATION_THRESHOLD);

        for (Integer i = 0; i < TEST_DONATION_THRESHOLD; i++) {
            testAppointments.add(TestUtil.createTestAppointment(scheduledId, currentDatetime));
            currentDatetime = currentDatetime.addDays(14);
        }
        insert testAppointments;

        List<Visit__c> testVisits = new List<Visit__c>();
        Id centerDonationTypeId = [SELECT Id FROM Center_Donation_Type__c LIMIT 1][0].Id;

        for (Integer i = 0; i < TEST_DONATION_THRESHOLD - 1; i++) {
            Visit__c testVisit = TestUtil.createVisit(donorAccounts[0].PersonContactId, centerDonationTypeId, testAppointments[i].Id);
            testVisit.Status__c = 'Complete';
            testVisit.Outcome__c = 'Donation';

            testVisits.add(testVisit);
        }
        insert testVisits;

        Visit__c crossDonationThresholdVisit = TestUtil.createVisit(donorAccounts[0].PersonContactId, centerDonationTypeId, testAppointments[TEST_DONATION_THRESHOLD - 1].Id);
        crossDonationThresholdVisit.Status__c = 'Complete';
        crossDonationThresholdVisit.Outcome__c = 'Donation';

        Test.startTest();
        // Should create normal transaction with Level 1 Rates
        DonorCompInvocable.handleCreateDonationTransactions(new List<List<Donor_Comp__e>> { new List<Donor_Comp__e>{ 
            new Donor_Comp__e(Donor_Number__c = donorAccounts[0].DonorId__c, Timestamp__c = Datetime.now())
        }});

        insert crossDonationThresholdVisit;

        // Should create transaction with threshold payments
        DonorCompInvocable.handleCreateDonationTransactions(new List<List<Donor_Comp__e>> { new List<Donor_Comp__e>{ 
            new Donor_Comp__e(Donor_Number__c = donorAccounts[0].DonorId__c, Timestamp__c = Datetime.now())
        }});
        Test.stopTest();

        List<Contact> donors = [
            SELECT Id, Loyalty_Level__r.Name, (SELECT Id, Amount_Currency__c, Amount_Points__c FROM Transactions__r ORDER BY Name ASC)
            FROM Contact
            WHERE Id IN (SELECT PersonContactId FROM Account WHERE Id = :donorAccounts[0].Id)
        ];

        Assert.areEqual('Level 2', donors[0].Loyalty_Level__r.Name, 'Donor should be Level 2 after 5 visits');
        Assert.areEqual(2, donors[0].Transactions__r.size(), 'Donor should have 2 transactions');
        
        // Level 1 Transaction
        Assert.areEqual(233, donors[0].Transactions__r[0].Amount_Currency__c, 'First Transaction should have Amount_Currency__c = 233');
        Assert.areEqual(1333, donors[0].Transactions__r[0].Amount_Points__c, 'First Transaction should have Amount_Points__c = 1333');

        // Level 2 Transaction
        Assert.areEqual(300, donors[0].Transactions__r[1].Amount_Currency__c, 'Last Transaction should have Amount_Currency__c = 333');
        Assert.areEqual(2000, donors[0].Transactions__r[1].Amount_Points__c, 'Last Transaction should have Amount_Points__c = 2333');
    }
}