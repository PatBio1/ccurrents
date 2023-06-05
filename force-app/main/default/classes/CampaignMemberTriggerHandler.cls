/**
 * Created by joshlequire1 on 5/31/23.
 */

public without sharing class CampaignMemberTriggerHandler extends TriggerFactory.BaseHandler {
    public override void beforeUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        updateTotalEligibleDonationCount((Map<Id, CampaignMember>) newMap);
    }

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
        List<Payment_Request__c> newPaymentRequests = new List<Payment_Request__c>();

        for (CampaignMember cm : newCampaignMemberMap.values()) {
            CampaignMember oldCampaignMember = oldCampaignMemberMap.get(cm.Id);
            if (cm.Incentive_Eligible__c &&
                (
                    (cm.Total_Eligible_Donation_Count__c > oldCampaignMember.Total_Eligible_Donation_Count__c) ||
                        (cm.Starting_Donation_Count__c > oldCampaignMember.Starting_Donation_Count__c) ||
                        (cm.Eligible_Donation_Count__c > oldCampaignMember.Eligible_Donation_Count__c)
                )
            ) {
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
                Name,
                Award_Point_Amount__c,
                Award_Dollar_Amount__c,
                Campaign__c,
                Minimum_Donation_Amount__c,
                Next_Campaign_Level__c,
                Message_Subject_Default__c,
                Message_Body_Default__c,
                Approval_Required__c,
                Campaign__r.Enable_Payment_Requests__c,
                Campaign__r.Member_Incentive_Life_Days__c,
                Campaign__r.Name
            FROM Campaign_Level__c
            WHERE Campaign__c IN :campaignsToCheck AND
            isActive__c = TRUE
        ]) {
            campaignLevelMap.put(String.valueOf(cl.Campaign__c + '-' + cl.Minimum_Donation_Amount__c), cl);
        }

        for (CampaignMember cm : campaignMemberMap.values()) {
            // Fix Total Eligible Count due to before & after update trigger timing; this won't be correct in this context, so we have to re-calc again here in this one.
            Integer totalCount = getCorrectTotalCount(cm);

            Campaign_Level__c clDetail = campaignLevelMap.get(String.valueOf(cm.CampaignId + '-' + totalCount));
            if (clDetail != null &&
                ((Date.valueOf(cm.CreatedDate).daysBetween(Date.today()) <= clDetail.Campaign__r.Member_Incentive_Life_Days__c) ||
                    clDetail.Campaign__r.Member_Incentive_Life_Days__c == null)
            ) {
                CampaignMember cmUpdate = new CampaignMember(
                    Id = cm.Id,
                    Campaign_Level__c = clDetail.Id
                );
                campaignMemberUpdates.add(cmUpdate);

                if (clDetail.Campaign__r.Enable_Payment_Requests__c) {
                    Payment_Request__c newPaymentRequest = createPaymentRequest(cm, clDetail);
                    newPaymentRequests.add(newPaymentRequest);
                }

            }
        }

        if (!campaignMemberUpdates.isEmpty()) {
            update campaignMemberUpdates;
        }

        if (!newPaymentRequests.isEmpty()) {
            insert newPaymentRequests;
        }

    }

    public static Payment_Request__c createPaymentRequest(CampaignMember cm, Campaign_Level__c cl) {
        String nameString = String.valueOf(cl.Campaign__r.Name + ' ' + cl.Name + ' Incentive Payment'
        ).left(80);
        Payment_Request__c newPaymentRequest = new Payment_Request__c(
            Name = nameString,
            Reason_Description__c = nameString.left(50),
            Amount_Dollars__c = cl.Award_Dollar_Amount__c,
            Amount_Points__c = cl.Award_Point_Amount__c,
            Donor__c = cm.ContactId,
            Visit__c = cm.Last_Related_Visit__c,
            Campaign_Member_Id__c = String.valueOf(cm.Id),
            Message_Subject__c = cl.Message_Subject_Default__c,
            Message_Body__c = cl.Message_Body_Default__c,
            Approval_Required__c = cl.Approval_Required__c
        );

        if(cl.Approval_Required__c) {
            newPaymentRequest.Status__c = Constants.PAYMENTREQUEST_STATUS_NEW;
        } else {
            newPaymentRequest.Status__c = Constants.PAYMENTREQUEST_STATUS_APPROVED;
        }

        return newPaymentRequest;
    }

    public static void updateTotalEligibleDonationCount(Map<Id, CampaignMember> newCMMap) {
        for (CampaignMember cm : newCMMap.values()) {
            fixCountValues(cm);
        }
    }

    public static CampaignMember fixCountValues(CampaignMember inputCM) {
        if (inputCM.Total_Eligible_Donation_Count__c == null) {
            inputCM.Total_Eligible_Donation_Count__c = 0;
        }

        if (inputCM.Eligible_Donation_Count__c == null) {
            inputCM.Eligible_Donation_Count__c = 0;
        }

        if (inputCM.Starting_Donation_Count__c == null) {
            inputCM.Starting_Donation_Count__c = 0;
        }

        inputCM.Total_Eligible_Donation_Count__c = getCorrectTotalCount(inputCM);

        return inputCM;
    }

    public static Integer getCorrectTotalCount(CampaignMember inputCM) {
        Integer totalCount = 0;
        Integer startCount = 0;
        Integer eligibleCount = 0;

        if (inputCM.Total_Eligible_Donation_Count__c != null) {
            totalCount = Integer.valueOf(inputCM.Total_Eligible_Donation_Count__c);
        }

        if (inputCM.Eligible_Donation_Count__c != null) {
            eligibleCount = Integer.valueOf(inputCM.Eligible_Donation_Count__c);
        }

        if (inputCM.Starting_Donation_Count__c != null) {
            startCount = Integer.valueOf(inputCM.Starting_Donation_Count__c);
        }

        totalCount = startCount + eligibleCount;

        return totalCount;
    }
}