/**
 * Created by joshlequire1 on 3/14/23.
 */
@IsTest
public with sharing class BroadcastActionInvocableTest {

    @IsTest
    static void testBehavior() {
        Datetime testDateTime = Datetime.now();
        User testUser = TestUtil.createAdminUser();
        TestUtil.VisitTestSetup testSetup = new TestUtil.VisitTestSetup();
        Account donor2 = new Account();
        Id donor2ContactId;
        AccountContactRelation acr = new AccountContactRelation();
        System.runAs(testUser) {
            testSetup = TestUtil.createFullTestVisitSetup('123456', testDateTime, true);
            donor2 = TestUtil.createTestDonor('3456');
            insert donor2;
            donor2ContactId = [SELECT PersonContactId FROM Account WHERE Id = :donor2.Id][0].PersonContactId;
            acr = TestUtil.createDonorCenterRelation(donor2ContactId, testSetup.CenterId);
            insert acr;
            User donor2User = TestUtil.createExperienceUserFromContactId(donor2ContactId);
        }

        BroadcastActionInvocableVariable testBar1 = new BroadcastActionInvocableVariable();
        testBar1.MessageType = 'Center Closure';
        testBar1.ClosureStartDatetime = testDateTime.addHours(-1);
        testBar1.ReopenDatetime = testDateTime.addHours(24);
        testBar1.Audience = 'Donors on Schedule';
        testBar1.DonorScheduleStart = testDateTime.date();
        testBar1.DonorScheduleEnd = testDateTime.addDays(1).date();
        testBar1.MessageContent = 'Message Content 1';
        testBar1.MessageExpirationDate = null;
        testBar1.CenterAccountId = testSetup.CenterId;
        testBar1.flowUser = testUser;
        testBar1.ScheduledSendDateTime = testDateTime;
        List<BroadcastActionInvocableVariable> testRequest1 = new List<BroadcastActionInvocableVariable>();
        testRequest1.add(testBar1);
        List<List<BroadcastActionInvocableVariable>> request1 = new List<List<BroadcastActionInvocableVariable>>();
        request1.add(testRequest1);

        BroadcastActionInvocableVariable testBar2 = new BroadcastActionInvocableVariable();
        testBar2.MessageType = 'Important Update';
        testBar2.ClosureStartDatetime = null;
        testBar2.ReopenDatetime = null;
        testBar2.Audience = 'All Donors for Center';
        testBar2.DonorScheduleStart = null;
        testBar2.DonorScheduleEnd = null;
        testBar2.MessageContent = 'Message Content 2';
        testBar2.MessageExpirationDate = null;
        testBar2.CenterAccountId = testSetup.CenterId;
        testBar2.flowUser = testUser;
        testBar2.ScheduledSendDateTime = testDateTime;
        List<BroadcastActionInvocableVariable> testRequest2 = new List<BroadcastActionInvocableVariable>();
        testRequest2.add(testBar2);
        List<List<BroadcastActionInvocableVariable>> request2 = new List<List<BroadcastActionInvocableVariable>>();
        request2.add(testRequest2);

        Test.startTest();
        List<BroadcastActionInvocable.BroadcastActionResponse> baResponse1 = BroadcastActionInvocable.executeBroadcastAction(request1);
        List<BroadcastActionInvocable.BroadcastActionResponse> baResponse2 = BroadcastActionInvocable.executeBroadcastAction(request2);
        Test.stopTest();

        Integer donorOnScheduleCount = 0;
        Integer allCenterDonorsCount = 0;
        for (BroadcastActionInvocable.BroadcastActionResponse br : baResponse1) {
            Assert.areEqual(1, br.donorCount);
            Assert.isTrue(br.finalMessageText.contains(testBar1.MessageContent));
            System.debug(br.messageRecords);
            for (Message__c message : br.messageRecords) {
                message.Name = 'Center Closure';
                Assert.areEqual(testSetup.VisitId, message.Visit__c);
                Assert.areEqual(testDateTime, message.Scheduled_Send_Time__c);
            }
        }

        for (BroadcastActionInvocable.BroadcastActionResponse br : baResponse2) {
            Assert.areEqual(2, br.donorCount);
            Assert.areEqual(testBar2.MessageContent, br.finalMessageText);
            for (Message__c message : br.messageRecords) {
                message.Name = 'Important Update';
                Assert.areEqual(testDateTime, message.Scheduled_Send_Time__c);
            }
        }
    }

}