/**
 * Created by joshlequire1 on 5/31/23.
 */

trigger CampaignMemberTrigger on CampaignMember (before update, after update) {
    TriggerFactory.dispatchHandler(CampaignMember.SObjectType, new CampaignMemberTriggerHandler());
}