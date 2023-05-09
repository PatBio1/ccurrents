public without sharing class MessageTriggerHandler extends TriggerFactory.BaseHandler {

    public override void afterInsert(Map<Id, SObject> newMap) {
        shareRecords((List<Message__c>) newMap.values());
    }

    private static void shareRecords(List<Message__c> messages) {
        Set<Id> accountIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();

        for (Message__c message : messages) {
            if (message.Center__c != null) {
                accountIds.add(message.Center__c);
            }

            if (message.Donor__c != null) {
                contactIds.add(message.Donor__c);
            }
        }

        Map<Id, Id> contactAccountIds = new Map<Id, Id>();

        if (contactIds.size() > 0) {
            List<User> users = [
                SELECT
                    Contact.AccountId
                FROM
                    User
                WHERE
                    ContactId IN :contactIds
            ];

            for (User user : users) {
                if (user.Contact.AccountId != null) {
                    accountIds.add(user.Contact.AccountId);
                    contactAccountIds.put(user.ContactId, user.Contact.AccountId);
                }
            }
        }

        Map<Id, Set<Id>> accountGroupIds = new Map<Id, Set<Id>>();

        if (accountIds.size() > 0) {
            List<AccountShare> accountShares = [
                SELECT
                    AccountId, UserOrGroupId
                FROM
                    AccountShare
                WHERE
                    AccountId IN :accountIds
                AND
                    RowCause = 'Manual'
            ];

            for (AccountShare accountShare : accountShares) {
                if (accountShare.UserOrGroupId.getSObjectType() == Group.SObjectType) {
                    Set<Id> groupIds = accountGroupIds.get(accountShare.AccountId);
                    if (groupIds == null) {
                        groupIds = new Set<Id>();
                        accountGroupIds.put(accountShare.AccountId, groupIds);
                    }

                    groupIds.add(accountShare.UserOrGroupId);
                }
            }
        }

        List<Message__share> messageShares = new List<Message__share>();

        for (Message__c message : messages) {
            if (message.Center__c != null && accountGroupIds.containsKey(message.Center__c)) {
                Set<Id> groupIds = accountGroupIds.get(message.Center__c);

                for (Id groupId : groupIds) {
                    Message__share messageShare = new Message__share();
                    messageShare.ParentId = message.Id;
                    messageShare.UserOrGroupId = groupId;
                    messageShare.RowCause = 'Manual';
                    messageShare.AccessLevel = 'Read';
                    messageShares.add(messageShare);
                }
            }

            if (message.Donor__c != null && contactAccountIds.containsKey(message.Donor__c)) {
                Id accountId = contactAccountIds.get(message.Donor__c);

                if (accountGroupIds.containsKey(accountId)) {
                    Set<Id> groupIds = accountGroupIds.get(accountId);

                    for (Id groupId : groupIds) {
                        Message__share groupMessageShare = new Message__share();
                        groupMessageShare.ParentId = message.Id;
                        groupMessageShare.UserOrGroupId = groupId;
                        groupMessageShare.RowCause = 'Manual';
                        groupMessageShare.AccessLevel = 'Read';
                        messageShares.add(groupMessageShare);
                    }
                }
            }
        }

        if (messageShares.size() > 0) {
            insert messageShares;
        }
    }

}