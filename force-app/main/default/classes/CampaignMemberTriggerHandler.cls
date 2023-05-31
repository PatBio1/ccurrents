/**
 * Created by joshlequire1 on 5/31/23.
 */

public without sharing class CampaignMemberTriggerHandler extends TriggerFactory.BaseHandler {

    public override void afterUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        incentiveCampaignPromotion((Map<Id, CampaignMember>) newMap, (Map<Id, CampaignMember>) oldMap);
    }

    public static void incentiveCampaignPromotion(Map<Id, CampaignMember> newCampaignMemberMap, Map<Id, CampaignMember> oldCampaignMemberMap) {
        Set<Id> campaignsToCheck = new Set<Id>();
        Map<Id, CampaignMember> campaignMemberMap = new Map<Id, CampaignMember>();
        Map<String, Campaign_Level__c> campaignLevelMap = new Map<String, Campaign_Level__c>();
        List<CampaignMember> campaignMemberUpdates = new List<CampaignMember>();

        for (CampaignMember cm : newCampaignMemberMap.values()) {
            if (cm.Eligible_Donation_Count__c > oldCampaignMemberMap.get(cm.Id).Eligible_Donation_Count__c) {
                campaignsToCheck.add(cm.CampaignId);
                campaignMemberMap.put(cm.Id, cm);
            }
        }

        if (campaignsToCheck.isEmpty()) {
            return;
        }

        // We're trusting that DonorCompInvocable.updateCampaignVisitCounter is firing only on ACTIVE Incentive Type Campaigns
        for (Campaign_Level__c cl : [
            SELECT Id,
                Award_Point_Amount__c,
                Award_Dollar_Amount__c,
                Campaign__c,
                Minimum_Donation_Amount__c,
                Next_Campaign_Level__c
            FROM Campaign_Level__c
            WHERE Campaign__c IN :campaignsToCheck AND
            isActive__c = TRUE
        ]) {
            campaignLevelMap.put(String.valueOf(cl.Campaign__c + '-' + cl.Minimum_Donation_Amount__c), cl);
        }

        for(CampaignMember cm : campaignMemberMap.values()) {
            if(campaignLevelMap.get(String.valueOf(cm.CampaignId + '-' + cm.Eligible_Donation_Count__c)) != null) {
                CampaignMember cmUpdate = new CampaignMember(
                  Id = cm.Id

                );
            }
        }

    }
}