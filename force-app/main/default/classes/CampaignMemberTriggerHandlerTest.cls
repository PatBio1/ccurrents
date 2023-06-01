/**
 * Created by joshlequire1 on 5/31/23.
 */
@IsTest
public without sharing class CampaignMemberTriggerHandlerTest {

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
                Award_Dollar_Amount__c = 50,
                Campaign__c = incentiveCampaign.Id,
                isActive__c = true,
                Minimum_Donation_Amount__c = 1
            ),
            new Campaign_Level__c(
                Name = 'Level 2',
                Award_Dollar_Amount__c = 50,
                Campaign__c = incentiveCampaign.Id,
                isActive__c = true,
                Minimum_Donation_Amount__c = 2
            )
        };

        insert incentiveCampaignLevels;

        Map<Integer, Id> incentiveCampaignLevelMap = new Map<Integer, Id>();

        for (Campaign_Level__c cl : incentiveCampaignLevels) {
            incentiveCampaignLevelMap.put(Integer.valueOf(cl.Minimum_Donation_Amount__c), cl.Id);
        }

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
        Assert.areEqual(incentiveCampaignLevelMap.get(1), cmUpdate1Check.Campaign_Level__c);

        CampaignMember cmUpdate2 = new CampaignMember(
            Id = testCampaignMember.Id,
            Eligible_Donation_Count__c = 2
        );

        update cmUpdate2;

        CampaignMember cmUpdate2Check = [SELECT Id, Eligible_Donation_Count__c, Campaign_Level__c FROM CampaignMember WHERE Id = :testCampaignMember.Id][0];

        // Verify change from 1 to 2
        Assert.areEqual(incentiveCampaignLevelMap.get(2), cmUpdate2Check.Campaign_Level__c);

        CampaignMember cmUdpate3 = new CampaignMember(
            Id = testCampaignMember.Id,
            Eligible_Donation_Count__c = 3
        );

        update cmUdpate3;

        // Verify no change from 2 to 3, because no level exists for this
        CampaignMember cmUpdate3Check = [SELECT Id, Eligible_Donation_Count__c, Campaign_Level__c FROM CampaignMember WHERE Id = :testCampaignMember.Id][0];

        Assert.areEqual(incentiveCampaignLevelMap.get(2), cmUpdate3Check.Campaign_Level__c);

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
        Assert.areEqual(incentiveCampaignLevelMap.get(2), cmUpdate3Check.Campaign_Level__c);

        Test.stopTest();

    }

}