/**
 * Created by joshlequire1 on 5/31/23.
 */

public without sharing class CampaignMemberTriggerHandler extends TriggerFactory.BaseHandler {

    public override void afterUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        incentiveCampaignPromotion((Map<Id, CampaignMember>) newMap, (Map<Id, CampaignMember>) oldMap);
    }

    // Move to helper class if & when necessary.
    // We're trusting that DonorCompInvocable.updateCampaignVisitCounter is firing only on ACTIVE Incentive Type Campaigns.
    public static void incentiveCampaignPromotion(Map<Id, CampaignMember> newCampaignMemberMap, Map<Id, CampaignMember> oldCampaignMemberMap) {
        Set<Id> campaignsToCheck = new Set<Id>();
        Map<Id, CampaignMember> campaignMemberMap = new Map<Id, CampaignMember>();
        Map<String, Campaign_Level__c> campaignLevelMap = new Map<String, Campaign_Level__c>();
        List<CampaignMember> campaignMemberUpdates = new List<CampaignMember>();

        for (CampaignMember cm : newCampaignMemberMap.values()) {
            CampaignMember oldCampaignMember = oldCampaignMemberMap.get(cm.Id);
            if ((cm.Eligible_Donation_Count__c > oldCampaignMember.Eligible_Donation_Count__c) ||
                (cm.Eligible_Donation_Count__c >= 1 && oldCampaignMember.Eligible_Donation_Count__c == null)) {
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
                Next_Campaign_Level__c,
                Campaign__r.Enable_Payment_Requests__c,
                Campaign__r.Member_Incentive_Life_Days__c
            FROM Campaign_Level__c
            WHERE Campaign__c IN :campaignsToCheck AND
            isActive__c = TRUE
        ]) {
            campaignLevelMap.put(String.valueOf(cl.Campaign__c + '-' + cl.Minimum_Donation_Amount__c), cl);
        }

        for (CampaignMember cm : campaignMemberMap.values()) {
            Campaign_Level__c clDetail = campaignLevelMap.get(String.valueOf(cm.CampaignId + '-' + cm.Eligible_Donation_Count__c));
            if (clDetail != null &&
                ((Date.valueOf(cm.CreatedDate).daysBetween(Date.today()) <= clDetail.Campaign__r.Member_Incentive_Life_Days__c) ||
                    clDetail.Campaign__r.Member_Incentive_Life_Days__c == null)
            ) {
                CampaignMember cmUpdate = new CampaignMember(
                    Id = cm.Id,
                    Campaign_Level__c = clDetail.Id
                );
                campaignMemberUpdates.add(cmUpdate);
            }
        }

        if (!campaignMemberUpdates.isEmpty()) {
            update campaignMemberUpdates;
        }
    }
}