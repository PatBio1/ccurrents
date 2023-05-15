/**
 * Created by joshlequire1 on 3/7/23.
 */

@IsTest
public with sharing class DonorCompInvocableTest {

    static Integer TEST_DONATION_THRESHOLD = 5;
    static Integer TEST_DONATION_THRESHOLD_WINDOW = 30;
    static String TEST_BONUS_LEVEL_NAME = 'Bonus Level 1';

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

        Level__c bonusLevel1 = new Level__c(Name = TEST_BONUS_LEVEL_NAME, Donation_Threshold__c = TEST_DONATION_THRESHOLD - 1, Threshold_Points__c = 333, Threshold_Payment__c = 33, isActive__c = true, isVisible__c = false);
        insert bonusLevel1;

        Account donorAccount1 = TestUtil.createDonor('123456');
        donorAccount1.Loyalty_Level__pc = testLevel1.Id;
        insert donorAccount1;

        Account donorAccount2 = TestUtil.createDonor('654321');
        donorAccount2.Loyalty_Level__pc = testLevel1.Id;
        insert donorAccount2;

        Campaign positiveTestCampaign = new Campaign(
            Name = 'Incentive Campaign',
            Type = 'Incentive',
            IsActive = true,
            StartDate = Date.today(),
            EndDate = Date.today().addDays(30),
            Status = 'In Progress'
        );

        insert positiveTestCampaign;

        Campaign negativeTestCampaign = new Campaign(
            Name = 'Email Campaign',
            Type = 'Email',
            IsActive = true,
            StartDate = Date.today(),
            EndDate = Date.today().addDays(30),
            Status = 'In Progress'
        );

        insert negativeTestCampaign;

        Proesis_Settings__c newSettings = new Proesis_Settings__c(Loyalty_Threshold_Window__c = TEST_DONATION_THRESHOLD_WINDOW);
        insert newSettings;
    }

    @IsTest
    static void testUpdateVisitStatusComplete() {
        List<Account> donorAccounts = [SELECT Id, DonorId__c, PersonContactId FROM Account WHERE DonorId__c != null];
        Id appointmentId = [SELECT Id FROM Appointment__c LIMIT 1][0].Id;
        Id centerDonationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1][0].Id;
        Id donor1ContactId = [SELECT PersonContactId FROM Account WHERE Id = :donorAccounts[0].Id][0].PersonContactId;

        Visit__c testVisit = TestUtil.createVisit(donor1ContactId, centerDonationType, appointmentId);
        insert testVisit;

        List<Campaign> testCampaigns = [SELECT Id FROM Campaign WHERE IsActive = TRUE];
        List<CampaignMember> newCampaignMembers = new List<CampaignMember>();

        for (Account donor : donorAccounts) {
            for (Campaign cp : testCampaigns) {
                CampaignMember newCampaignMember = new CampaignMember(
                    CampaignId = cp.Id,
                    ContactId = donor.PersonContactId
                );
                newCampaignMembers.add(newCampaignMember);
            }
        }

        insert newCampaignMembers;

        for(CampaignMember newCampaignMember : newCampaignMembers) {
            Test.setCreatedDate(newCampaignMember.Id, Datetime.now().addDays(-1));
        }

        List<Donor_Comp__e> donorCompEvents = new List<Donor_Comp__e>{
            new Donor_Comp__e(Donor_Number__c = donorAccounts[0].DonorId__c, Timestamp__c = Datetime.now().addHours(1), Collection_Volume__c = 555, Collection_Number__c = 'collection number', hasException__c = 0),
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

        List<CampaignMember> cmChecks = [SELECT Id, Eligible_Donation_Count__c FROM CampaignMember WHERE Eligible_Donation_Count__c > 0];

        Assert.areEqual(Constants.VISIT_STATUS_COMPLETE, compVisits[0].Status__c);
        Assert.areEqual(Constants.VISIT_OUTCOME_DONATION, compVisits[0].Outcome__c);
        Assert.areEqual(donorCompEvents[0].Timestamp__c, compVisits[0].Donation_Complete__c);
        Assert.areEqual(donorCompEvents[0].Collection_Number__c, compVisits[0].Collection_Number__c);
        Assert.areEqual(donorCompEvents[0].Collection_Volume__c, compVisits[0].Donation_Volume__c);

        Assert.areEqual(1, cmChecks.size());
        Assert.areEqual(1, cmChecks[0].Eligible_Donation_Count__c);
    }

    @IsTest
    static void testHandleCreateDonationTransactions() {
        List<Account> donorAccounts = [SELECT Id, PersonContactId, DonorId__c FROM Account WHERE DonorId__c != null LIMIT 1];

        // Create Active Payment Methods for the selected donor to ensure the addFunds method is called
        List<Payment_Method__c> testPaymentMethods = new List<Payment_Method__c>();
        for(Account donorAccount : donorAccounts) {
            testPaymentMethods.add(new Payment_Method__c(
                Name = 'Onbe Test Card', Donor__c = donorAccount.PersonContactId, Account_Number__c = '1234567890', Account_Token__c = '1050', Is_Active__c = true, isDefault__c = true, Expiration__c = Date.today().addYears(1)
            ));
        }
        insert testPaymentMethods;

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

        // Set mock for the 'addFunds' callout
        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        // Should create normal transaction with Level 1 Rates
        DonorCompInvocable.handleCreateDonationTransactions(new List<List<Donor_Comp__e>>{
            new List<Donor_Comp__e>{
                new Donor_Comp__e(Donor_Number__c = donorAccounts[0].DonorId__c, Timestamp__c = Datetime.now())
            }
        });

        insert crossDonationThresholdVisit;

        // Should create transaction with threshold payments
        DonorCompInvocable.handleCreateDonationTransactions(new List<List<Donor_Comp__e>>{
            new List<Donor_Comp__e>{
                new Donor_Comp__e(Donor_Number__c = donorAccounts[0].DonorId__c, Timestamp__c = Datetime.now())
            }
        });
        Test.stopTest();

        List<Contact> donors = [
            SELECT Id, Loyalty_Level__r.Name, (
                SELECT Id, Amount_Currency__c, Amount_Points__c 
                FROM Transactions__r 
                ORDER BY Name ASC
            )
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

    @IsTest 
    static void testHandleCheckLoyaltyThresholdWindow() {
        List<Account> donorAccounts = [SELECT Id, PersonContactId, DonorId__c FROM Account WHERE DonorId__c != null LIMIT 1];

        List<Appointment__c> testAppointments = new List<Appointment__c>();
        Id scheduledId = [SELECT Id FROM Schedule__c LIMIT 1]?.Id;
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

        // Create some promotion transaction line items in order to prevent the donor from receiving a threshold payment
        List<Transaction__c> testTransactions = new List<Transaction__c>();
        List<Txn_Line_Item__c> promoLineItems = new List<Txn_Line_Item__c>();

        for(Account donorAccount : donorAccounts) {
            testTransactions.add(new Transaction__c(Donor__c = donorAccount.PersonContactId, Visit__c = testVisits[testVisits.size() - 1].Id, Type__c = 'Debit'));
        }
        insert testTransactions;

        Level__c bonusLevel = [SELECT Id FROM Level__c WHERE Name = :TEST_BONUS_LEVEL_NAME LIMIT 1];
        for(Transaction__c testTransaction : testTransactions) {
            promoLineItems.add(new Txn_Line_Item__c(Transaction__c = testTransaction.Id, Promotion_Level__c = bonusLevel.Id));
        }
        insert promoLineItems;

        // Set the CreatedDate to be inside the threshold window
        for(Txn_Line_Item__c promoLineItem : promoLineItems) {
            Test.setCreatedDate(promoLineItem.Id, Datetime.now().addDays(-TEST_DONATION_THRESHOLD_WINDOW + 1));
        }

        Visit__c crossDonationThresholdVisit = TestUtil.createVisit(donorAccounts[0].PersonContactId, centerDonationTypeId, testAppointments[TEST_DONATION_THRESHOLD - 1].Id);
        crossDonationThresholdVisit.Status__c = 'Complete';
        crossDonationThresholdVisit.Outcome__c = 'Donation';

        Test.startTest();
        // Should create normal transaction with Level 1 Rates
        DonorCompInvocable.handleCreateDonationTransactions(new List<List<Donor_Comp__e>>{
            new List<Donor_Comp__e>{
                new Donor_Comp__e(Donor_Number__c = donorAccounts[0].DonorId__c, Timestamp__c = Datetime.now())
            }
        });

        insert crossDonationThresholdVisit;

        // Should create transaction with threshold payments
        DonorCompInvocable.handleCreateDonationTransactions(new List<List<Donor_Comp__e>>{
            new List<Donor_Comp__e>{
                new Donor_Comp__e(Donor_Number__c = donorAccounts[0].DonorId__c, Timestamp__c = Datetime.now())
            }
        });
        Test.stopTest();

        List<Contact> donors = [
            SELECT Id, Loyalty_Level__r.Name, (
                SELECT Id, Amount_Currency__c, Amount_Points__c 
                FROM Transactions__r
                WHERE Amount_Currency__c > 0 
                ORDER BY Name ASC
            )
            FROM Contact
            WHERE Id IN (SELECT PersonContactId FROM Account WHERE Id = :donorAccounts[0].Id)
        ];

        Assert.areEqual('Level 2', donors[0].Loyalty_Level__r.Name, 'Donor should be Level 2 after 5 visits');
        Assert.areEqual(2, donors[0].Transactions__r.size(), 'Donor should have 2 transactions');

        // Level 1 Transaction
        Assert.areEqual(200, donors[0].Transactions__r[0].Amount_Currency__c, 'First Transaction should have Amount_Currency__c = 233');
        Assert.areEqual(1000, donors[0].Transactions__r[0].Amount_Points__c, 'First Transaction should have Amount_Points__c = 1333');

        // Level 2 Transaction
        Assert.areEqual(300, donors[0].Transactions__r[1].Amount_Currency__c, 'Last Transaction should have Amount_Currency__c = 333');
        Assert.areEqual(2000, donors[0].Transactions__r[1].Amount_Points__c, 'Last Transaction should have Amount_Points__c = 2333');
    }

    @IsTest 
    static void testHandleCreateDonationMessage() {
        List<Account> donorAccounts = [SELECT Id, PersonContactId, DonorId__c FROM Account WHERE DonorId__c != null LIMIT 1];
        Id scheduledId = [SELECT Id FROM Schedule__c LIMIT 1]?.Id;

        List<Appointment__c> testAppointments = new List<Appointment__c>();
        Datetime currentDatetime = Datetime.now().addDays(-14 * (TEST_DONATION_THRESHOLD + 1));

        for (Integer i = 0; i <= TEST_DONATION_THRESHOLD + 1; i++) {
            testAppointments.add(TestUtil.createTestAppointment(scheduledId, currentDatetime));
            currentDatetime = currentDatetime.addDays(14);
        }
        insert testAppointments;

        List<Visit__c> testVisits = new List<Visit__c>();
        Id centerDonationTypeId = [SELECT Id FROM Center_Donation_Type__c LIMIT 1][0].Id;

        for (Integer i = 0; i <= TEST_DONATION_THRESHOLD; i++) {
            Visit__c testVisit = TestUtil.createVisit(donorAccounts[0].PersonContactId, centerDonationTypeId, testAppointments[i].Id);
            testVisit.Status__c = 'Complete';
            testVisit.Outcome__c = 'Donation';

            testVisits.add(testVisit);
        }
        insert testVisits;

        Test.startTest();
        DonorCompInvocable.handleCreateDonationTransactions(new List<List<Donor_Comp__e>>{
            new List<Donor_Comp__e>{
                new Donor_Comp__e(Donor_Number__c = donorAccounts[0].DonorId__c, Timestamp__c = Datetime.now())
            }
        });
        Test.stopTest();

        List<Contact> donors = [
            SELECT Id, Loyalty_Level__r.Name, (
                SELECT Id, CreatedDate, Name, Message_Handler_Type__c, Body__c, Visit__c, Transaction__c, Transaction__r.Visit__c, Trigger_Marketing_Cloud__c
                FROM Messages__r
            )
            FROM Contact
            WHERE Id IN (SELECT PersonContactId FROM Account WHERE Id = :donorAccounts[0].Id)
        ];

        Assert.areEqual(1, donors[0].Messages__r.size(), 'Donor should have 1 message');

        // Regular Donation Message
        Assert.areEqual(System.label.Donation_Payment_Message_Title, donors[0].Messages__r[0].Name, 'Message should have Name = ' + System.label.Donation_Payment_Message_Title);
        Assert.areEqual(Constants.DONATION_PAYMENT_MESSAGE_HANDLER, donors[0].Messages__r[0].Message_Handler_Type__c, 'Message should have Message_Handler_Type__c = ' + Constants.DONATION_PAYMENT_MESSAGE_HANDLER);
        Assert.areEqual(System.label.Donation_Payment_Message_Body, donors[0].Messages__r[0].Body__c, 'Message should have Body = ' + System.label.Donation_Payment_Message_Body);
        Assert.areEqual(testVisits[testVisits.size() - 1].Id, donors[0].Messages__r[0].Visit__c, 'Message should have Visit__c = ' + testVisits[testVisits.size() - 1].Id);
        Assert.isNotNull(donors[0].Messages__r[0].Transaction__c, 'Message should have Transaction__c');
        Assert.areEqual(testVisits[testVisits.size() - 1].Id, donors[0].Messages__r[0].Transaction__r.Visit__c, 'The linked transaction should be the transaction linked to the last visit');
        Assert.isTrue(donors[0].Messages__r[0].Trigger_Marketing_Cloud__c, 'Message should have Trigger_Marketing_Cloud__c = true');
    }

    @IsTest 
    static void testHandleCreateLoyaltyDonationMessage() {
        List<Account> donorAccounts = [SELECT Id, PersonContactId, DonorId__c FROM Account WHERE DonorId__c != null LIMIT 1];
        Id scheduledId = [SELECT Id FROM Schedule__c LIMIT 1]?.Id;

        List<Appointment__c> testAppointments = new List<Appointment__c>();
        Datetime currentDatetime = Datetime.now().addDays(-14 * (TEST_DONATION_THRESHOLD + 1));

        for (Integer i = 0; i < TEST_DONATION_THRESHOLD + 1; i++) {
            testAppointments.add(TestUtil.createTestAppointment(scheduledId, currentDatetime));
            currentDatetime = currentDatetime.addDays(14);
        }
        insert testAppointments;

        List<Visit__c> testVisits = new List<Visit__c>();
        Id centerDonationTypeId = [SELECT Id FROM Center_Donation_Type__c LIMIT 1][0].Id;

        for (Integer i = 0; i < TEST_DONATION_THRESHOLD; i++) {
            Visit__c testVisit = TestUtil.createVisit(donorAccounts[0].PersonContactId, centerDonationTypeId, testAppointments[i].Id);
            testVisit.Status__c = 'Complete';
            testVisit.Outcome__c = 'Donation';

            testVisits.add(testVisit);
        }
        insert testVisits;

        Test.startTest();
        DonorCompInvocable.handleCreateDonationTransactions(new List<List<Donor_Comp__e>>{
            new List<Donor_Comp__e>{
                new Donor_Comp__e(Donor_Number__c = donorAccounts[0].DonorId__c, Timestamp__c = Datetime.now())
            }
        });
        Test.stopTest();

        List<Contact> donors = [
            SELECT Id, Loyalty_Level__r.Name, (
                SELECT Id, CreatedDate, Name, Message_Handler_Type__c, Body__c, Visit__c, Transaction__c, Transaction__r.Visit__c, Trigger_Marketing_Cloud__c
                FROM Messages__r
            )
            FROM Contact
            WHERE Id IN (SELECT PersonContactId FROM Account WHERE Id = :donorAccounts[0].Id)
        ];

        Assert.areEqual(1, donors[0].Messages__r.size(), 'Donor should have 1 message');

        // Loyalty Donation Message
        Assert.areEqual(System.label.Loyalty_Donation_Payment_Message_Title, donors[0].Messages__r[0].Name, 'Message should have Name = ' + System.label.Loyalty_Donation_Payment_Message_Title);
        Assert.areEqual(Constants.LOYALTY_DONATION_PAYMENT_MESSAGE_HANDLER, donors[0].Messages__r[0].Message_Handler_Type__c, 'Message should have Message_Handler_Type__c = ' + Constants.LOYALTY_DONATION_PAYMENT_MESSAGE_HANDLER);
        Assert.areEqual(System.label.Loyalty_Donation_Payment_Message_Body, donors[0].Messages__r[0].Body__c, 'Message should have Body = ' + System.label.Loyalty_Donation_Payment_Message_Body);
        Assert.areEqual(testVisits[testVisits.size() - 1].Id, donors[0].Messages__r[0].Visit__c, 'Message should have Visit__c = ' + testVisits[testVisits.size() - 1].Id);
        Assert.isNotNull(donors[0].Messages__r[0].Transaction__c, 'Message should have Transaction__c');
        Assert.areEqual(testVisits[testVisits.size() - 1].Id, donors[0].Messages__r[0].Transaction__r.Visit__c, 'The linked transaction should be the transaction linked to the last visit');
        Assert.isTrue(donors[0].Messages__r[0].Trigger_Marketing_Cloud__c, 'Message should have Trigger_Marketing_Cloud__c = true');
    }

    @IsTest 
    static void testMissingPaymentTask() {
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

        // Set mock for the 'addFunds' callout
        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        // Should create normal transaction with Level 1 Rates
        DonorCompInvocable.handleCreateDonationTransactions(new List<List<Donor_Comp__e>>{
            new List<Donor_Comp__e>{
                new Donor_Comp__e(Donor_Number__c = donorAccounts[0].DonorId__c, Timestamp__c = Datetime.now())
            }
        });
        Test.stopTest();

        Assert.areEqual(donorAccounts.size(), [SELECT count() FROM Task WHERE Subject = :Constants.MISSING_PAYMENT_METHOD_TASK_SUBJECT], 'Should have created a Missing Payment Task');
    }

    @IsTest 
    static void testSetLastUsedCenter() {
        List<Account> donorAccounts = [SELECT Id, PersonContactId, DonorId__c FROM Account WHERE DonorId__c != null LIMIT 1];
        Center_Donation_Type__c centerDonationType = [SELECT Id, Center__c FROM Center_Donation_Type__c LIMIT 1];
        Appointment__c targetAppointment = [SELECT Id FROM Appointment__c LIMIT 1];

        Visit__c testVisit = TestUtil.createVisit(donorAccounts[0].PersonContactId, centerDonationType.Id, targetAppointment.Id);
        testVisit.Status__c = 'Complete';
        testVisit.Outcome__c = 'Donation';
        insert testVisit;

        // Set mock for the 'addFunds' callout
        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        DonorCompInvocable.handleCreateDonationTransactions(new List<List<Donor_Comp__e>>{
            new List<Donor_Comp__e>{
                new Donor_Comp__e(Donor_Number__c = donorAccounts[0].DonorId__c, Timestamp__c = Datetime.now())
            }
        });
        Test.stopTest();

        List<Account> updatedDonorAccounts = [SELECT Id, Last_Used_Center__pc FROM Account WHERE Id IN :donorAccounts];
        for(Account donorAccount : updatedDonorAccounts) {
            Assert.areEqual(centerDonationType.Center__c, donorAccount.Last_Used_Center__pc, 'Donor should have Last_Used_Center__c = ' + centerDonationType.Center__c);
        }
    }
}