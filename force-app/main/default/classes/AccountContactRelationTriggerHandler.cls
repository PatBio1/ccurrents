public without sharing class AccountContactRelationTriggerHandler extends TriggerFactory.BaseHandler {

    public override void afterInsert(Map<Id, SObject> newMap) {
        shareRecords((List<AccountContactRelation>) newMap.values());
    }

    private static void shareRecords(List<AccountContactRelation> accountContactRelations) {
        Set<Id> accountContactRelationIds = new Set<Id>();

        for (AccountContactRelation accountContactRelation : accountContactRelations) {
            if (accountContactRelation.Roles == 'Donor') {
                accountContactRelationIds.add(accountContactRelation.Id);
            }
        }

        if (accountContactRelationIds.size() > 0) {
            Boolean isGuestUser = ([SELECT COUNT() FROM PermissionSetAssignment WHERE PermissionSet.Label = :Constants.EXPERIENCE_GUEST_PERMISSION_SET_NAME AND AssigneeId = :UserInfo.getUserId()] > 0);

            if (isGuestUser) {
                shareRecordsAsync(accountContactRelationIds);
            } else {
                shareRecords(accountContactRelationIds);
            }
        }
    }

    @future(callout=true)
    public static void shareRecordsAsync(Set<Id> accountContactRelationIds) {
        MobileGuestService.ShareRecordsRequest shareRecordsRequest = new MobileGuestService.ShareRecordsRequest();
        shareRecordsRequest.accountContactRelationIds = new List<Id>(accountContactRelationIds);

        String endpoint = MobileGuestService.ENDPOINT + MobileGuestService.SHARE_RECORDS_PATH;

        HttpRequest httpRequest = new HttpRequest();
        httpRequest.setMethod('POST');
        httpRequest.setEndpoint(endpoint);
        httpRequest.setHeader('Content-Type', 'application/json;charset=UTF-8');
        httpRequest.setBody(JSON.serialize(shareRecordsRequest));

        HttpResponse httpResponse = new Http().send(httpRequest);
    }

    public static void shareRecords(Set<Id> accountContactRelationIds) {
        List<AccountContactRelation> accountContactRelations = [
            SELECT
                AccountId, Contact.AccountId
            FROM
                AccountContactRelation
            WHERE
                Id IN :accountContactRelationIds
        ];

        Set<Id> centerAccountIds = new Set<Id>();
        Set<Id> donorAccountIds = new Set<Id>();

        for (AccountContactRelation accountContactRelation : accountContactRelations) {
            centerAccountIds.add(accountContactRelation.AccountId);
            donorAccountIds.add(accountContactRelation.Contact.AccountId);
        }

        List<AccountShare> accountShares = [
            SELECT
                AccountId, UserOrGroupId, AccountAccessLevel, CaseAccessLevel, OpportunityAccessLevel
            FROM
                AccountShare
            WHERE
                (AccountId IN :centerAccountIds OR AccountId IN :donorAccountIds)
            AND
                RowCause = 'Manual'
        ];

        Map<Id, List<AccountShare>> centerAccountShares = new Map<Id, List<AccountShare>>();
        Set<String> accountUserOrGroupIds = new Set<String>();

        for (AccountShare accountShare : accountShares) {
            if (centerAccountIds.contains(accountShare.AccountId)) {
                List<AccountShare> accountShareList = centerAccountShares.get(accountShare.AccountId);
                if (accountShareList == null) {
                    accountShareList = new List<AccountShare>();
                    centerAccountShares.put(accountShare.AccountId, accountShareList);
                }

                accountShareList.add(accountShare);
            } else {
                String accountUserOrGroupId = accountShare.AccountId + '-' + accountShare.UserOrGroupId;
                accountUserOrGroupIds.add(accountUserOrGroupId);
            }
        }

        List<AccountShare> accountSharesToInsert = new List<AccountShare>();

        for (AccountContactRelation accountContactRelation : accountContactRelations) {
            List<AccountShare> centerAccountShareList = centerAccountShares.get(accountContactRelation.AccountId);

            if (centerAccountShareList != null) {
                for (AccountShare centerAccountShare : centerAccountShareList) {
                    String accountUserOrGroupId = accountContactRelation.Contact.AccountId + '-' + centerAccountShare.UserOrGroupId;

                    if (!accountUserOrGroupIds.contains(accountUserOrGroupId)) {
                        AccountShare accountShare = new AccountShare();
                        accountShare.AccountId = accountContactRelation.Contact.AccountId;
                        accountShare.UserOrGroupId = centerAccountShare.UserOrGroupId;
                        accountShare.RowCause = 'Manual';
                        accountShare.AccountAccessLevel = centerAccountShare.AccountAccessLevel;
                        accountShare.CaseAccessLevel = centerAccountShare.CaseAccessLevel;
                        accountShare.OpportunityAccessLevel = centerAccountShare.OpportunityAccessLevel;
                        accountSharesToInsert.add(accountShare);

                        accountUserOrGroupIds.add(accountUserOrGroupId);
                    }
                }
            }
        }

        if (accountSharesToInsert.size() > 0) {
            insert accountSharesToInsert;
        }
    }

}