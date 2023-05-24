List<AccountContactRelation> acrs = [
    SELECT
        AccountId, Contact.AccountId
    FROM
        AccountContactRelation
    WHERE
        Roles = 'Donor'
];

Set<Id> centerAccountIds = new Set<Id>();
Set<Id> donorAccountIds = new Set<Id>();

for (AccountContactRelation acr : acrs) {
    centerAccountIds.add(acr.AccountId);
    donorAccountIds.add(acr.Contact.AccountId);
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

for (AccountContactRelation acr : acrs) {
    List<AccountShare> centerAccountShareList = centerAccountShares.get(acr.AccountId);

    if (centerAccountShareList != null) {
        for (AccountShare centerAccountShare : centerAccountShareList) {
            String accountUserOrGroupId = acr.Contact.AccountId + '-' + centerAccountShare.UserOrGroupId;

            if (!accountUserOrGroupIds.contains(accountUserOrGroupId)) {
                AccountShare accountShare = new AccountShare();
                accountShare.AccountId = acr.Contact.AccountId;
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