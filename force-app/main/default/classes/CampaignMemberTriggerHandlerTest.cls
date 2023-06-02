/**
 * Created by joshlequire1 on 5/31/23.
 */
@IsTest
public without sharing class CampaignMemberTriggerHandlerTest {

    @IsTest
    static void testTotalEligibleCountUpdate() {
        Account testPerson = TestUtil.createDonor('234567');
        insert testPerson;

        Id personContactId = [SELECT PersonContactId FROM Account WHERE Id = :testPerson.Id][0].PersonContactId;

        Campaign testCampaign = new Campaign(
            Name = 'Test Campaign',
            IsActive = true
        );

        insert testCampaign;

        CampaignMember testCampaignMember = new CampaignMember(
            CampaignId = testCampaign.Id,
            ContactId = personContactId
        );

        insert testCampaignMember;

        update new CampaignMember(
            Id = testCampaignMember.Id,
            Starting_Donation_Count__c = 1
        );

        CampaignMember cmCheck1 = [
            SELECT Id,
                Starting_Donation_Count__c,
                Eligible_Donation_Count__c,
                Total_Eligible_Donation_Count__c
            FROM CampaignMember
        ]
            [0];

        Assert.areEqual(0, cmCheck1.Eligible_Donation_Count__c);
        Assert.areEqual(1, cmCheck1.Total_Eligible_Donation_Count__c);
    }

    @IsTest
    static void testIncentivePromotion() {
        Account testPerson = TestUtil.createDonor('123456');
        insert testPerson;

        Id personContactId = [SELECT PersonContactId FROM Account WHERE Id = :testPerson.Id][0].PersonContactId;

        Campaign incentiveCampaign = new Campaign(
            Name = 'Test Campaign',
            Type = Constants.CAMPAIGN_TYPE_INCENTIVE,
            IsActive = true,
            Enable_Payment_Requests__c = true,
            Member_Incentive_Life_Days__c = 10
        );

        insert incentiveCampaign;

        List<Campaign_Level__c> incentiveCampaignLevels = new List<Campaign_Level__c>{
            new Campaign_Level__c(
                Name = 'Level 1',
                Award_Dollar_Amount__c = 100,
                Campaign__c = incentiveCampaign.Id,
                isActive__c = true,
                Minimum_Donation_Amount__c = 1,
                Message_Subject_Default__c = 'You achieved level 1!',
                Message_Body_Default__c = 'Here\'s some sweet moolah'
            ),
            new Campaign_Level__c(
                Name = 'Level 2',
                Award_Dollar_Amount__c = 50,
                Campaign__c = incentiveCampaign.Id,
                isActive__c = true,
                Minimum_Donation_Amount__c = 2,
                Message_Subject_Default__c = 'You achieved level 2!',
                Message_Body_Default__c = 'Here\'s some more sweet moolah'
            )
        };

        insert incentiveCampaignLevels;

        Map<Integer, Campaign_Level__c> incentiveCampaignLevelMap = new Map<Integer, Campaign_Level__c>();

        for (Campaign_Level__c cl : incentiveCampaignLevels) {
            incentiveCampaignLevelMap.put(Integer.valueOf(cl.Minimum_Donation_Amount__c), cl);
        }

        // Expects Incentive_Eligible__c to default to TRUE; test will fail (as expected) if that changes.
        CampaignMember testCampaignMember = new CampaignMember(
            ContactId = personContactId,
            CampaignId = incentiveCampaign.Id
        );

        insert testCampaignMember;

        Test.startTest();
        CampaignMember cmUpdate1 = new CampaignMember(
            Id = testCampaignMember.Id,
            Eligible_Donation_Count__c = 1
        );

        update cmUpdate1;

        CampaignMember cmUpdate1Check = [SELECT Id, Eligible_Donation_Count__c, Campaign_Level__c FROM CampaignMember WHERE Id = :testCampaignMember.Id][0];

        // Verify change from null value to 1
        Assert.areEqual(incentiveCampaignLevelMap.get(1).Id, cmUpdate1Check.Campaign_Level__c);

        CampaignMember cmUpdate2 = new CampaignMember(
            Id = testCampaignMember.Id,
            Eligible_Donation_Count__c = 2
        );

        update cmUpdate2;

        CampaignMember cmUpdate2Check = [SELECT Id, Eligible_Donation_Count__c, Campaign_Level__c FROM CampaignMember WHERE Id = :testCampaignMember.Id][0];

        // Verify change from 1 to 2
        Assert.areEqual(incentiveCampaignLevelMap.get(2).Id, cmUpdate2Check.Campaign_Level__c);

        CampaignMember cmUdpate3 = new CampaignMember(
            Id = testCampaignMember.Id,
            Eligible_Donation_Count__c = 3
        );

        update cmUdpate3;

        // Verify no change from 2 to 3, because no level exists for this
        CampaignMember cmUpdate3Check = [SELECT Id, Eligible_Donation_Count__c, Campaign_Level__c FROM CampaignMember WHERE Id = :testCampaignMember.Id][0];

        Assert.areEqual(incentiveCampaignLevelMap.get(2).Id, cmUpdate3Check.Campaign_Level__c);

        // Change Incentive Life, test result
        Campaign incentiveCampaignUpdate = new Campaign(
            Id = incentiveCampaign.Id,
            Member_Incentive_Life_Days__c = -1
        );

        update incentiveCampaignUpdate;

        CampaignMember cmUpdate4 = new CampaignMember(
            Id = testCampaignMember.Id,
            Eligible_Donation_Count__c = 1
        );

        CampaignMember cmUpdate4Check = [SELECT Id, Eligible_Donation_Count__c, Campaign_Level__c FROM CampaignMember WHERE Id = :testCampaignMember.Id][0];

        // Should be no change
        Assert.areEqual(incentiveCampaignLevelMap.get(2).Id, cmUpdate3Check.Campaign_Level__c);

        Test.stopTest();

        for (Payment_Request__c pr : [
            SELECT Id,
                Name,
                Reason_Description__c,
                Amount_Dollars__c,
                Amount_Points__c,
                Status__c,
                Donor__c,
                Visit__c,
                Campaign_Member_Id__c,
                Message_Subject__c,
                Message_Body__c
            FROM Payment_Request__c
        ]) {
            Assert.areEqual(pr.Donor__c, personContactId);
            Assert.areEqual(testCampaignMember.Id, pr.Campaign_Member_Id__c);
            Assert.areEqual(Constants.PAYMENTREQUEST_STATUS_NEW, pr.Status__c);
            if (pr.Name.contains('Level 1')) {
                Assert.areEqual(100, pr.Amount_Dollars__c);
                Assert.areEqual('You achieved level 1!', pr.Message_Subject__c);
                Assert.areEqual('Here\'s some sweet moolah', pr.Message_Body__c);
            } else {
                Assert.areEqual(50, pr.Amount_Dollars__c);
                Assert.areEqual('You achieved level 2!', pr.Message_Subject__c);
                Assert.areEqual('Here\'s some more sweet moolah', pr.Message_Body__c);
            }
        }
    }
}