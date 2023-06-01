/**
 * Created by joshlequire1 on 2/28/23.
 */

public without sharing class LeadTriggerHandler extends TriggerFactory.BaseHandler {
    public static Boolean bypassTrigger = false;

    public override void afterUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        if (bypassTrigger) {
            return;
        }

        Set<Id> convertedLeadIds = getConvertedLeadIds((Map<Id, Lead>) oldMap, (Map<Id, Lead>) newMap);

        if (!convertedLeadIds.isEmpty()) {
            updateConsentTransactionLinksOnConversion((Map<Id, Lead>) newMap, convertedLeadIds);
            updateLegacyDonorMigratedData((Map<Id, Lead>) newMap);
        }
    }

    private static Set<Id> getConvertedLeadIds(Map<Id, Lead> oldLeadMap, Map<Id, Lead> newLeadMap) {
        Set<Id> convertedLeadIds = new Set<Id>();

        for (Lead ld : newLeadMap.values()) {
            if (ld.IsConverted && ld.IsConverted != oldLeadMap.get(ld.Id).IsConverted) {
                convertedLeadIds.add(ld.Id);
            }
        }
        return convertedLeadIds;
    }

    public static void updateConsentTransactionLinksOnConversion(Map<Id, Lead> newLeadMap, Set<Id> convertedLeadIds) {
        List<Consent_Transaction__c> consentTransactionsToUpdate = [SELECT Id, Lead__c, Contact__c FROM Consent_Transaction__c WHERE Lead__c IN :convertedLeadIds];

        if (!consentTransactionsToUpdate.isEmpty()) {
            List<Consent_Transaction__c> consentTransactionsUpdates = new List<Consent_Transaction__c>();
            for (Consent_Transaction__c ct : consentTransactionsToUpdate) {
                Consent_Transaction__c ctUpdate = new Consent_Transaction__c(Id = ct.Id);
                ctUpdate.Contact__c = newLeadMap.get(ct.Lead__c).ConvertedContactId;
                consentTransactionsUpdates.add(ctUpdate);
            }

            update consentTransactionsUpdates;
        }
    }

    public static void updateLegacyDonorMigratedData(Map<Id, Lead> newLeadMap) {
        List<Account> accountUpdates = new List<Account>();
        Set<Id> accountIdsInScope = new Set<Id>();
        Set<Id> contactIdsInScope = new Set<Id>();
        Map<Id, Lead> convertedAccountIdToLeadMap = new Map<Id, Lead>();
        Map<Id, Lead> convertedContactIdToLeadMap = new Map<Id, Lead>();
        Map<Id, Account> accountUpdateMap = new Map<Id, Account>();
        List<Task> taskUpdates = new List<Task>();

        for (Lead ld : newLeadMap.values()) {
            if (ld.isLegacyDonor__c) {
                accountIdsInScope.add(ld.ConvertedAccountId);
                convertedAccountIdToLeadMap.put(ld.ConvertedAccountId, ld);
            }
        }

        if (!accountIdsInScope.isEmpty()) {
            for (Account acct : [
                SELECT Id,
                    Date_Migrated__pc,
                    Last_Donation_Date_Migrated__pc,
                    Donations_Last_365_Days_Migrated__pc,
                    First_Visit_Code__c,
                    PersonContactId
                FROM Account
                WHERE Id IN :accountIdsInScope
            ]) {
                Lead convertedLead = convertedAccountIdToLeadMap.get(acct.Id);
                Account acctUpdate = new Account (
                    Id = acct.Id,
                    isLegacyDonor__pc = true,
                    Date_Migrated__pc = convertedLead.Date_Migrated__c,
                    Last_Donation_Date_Migrated__pc = convertedLead.Last_Donation_Date_Migrated__c,
                    Donations_Last_365_Days_Migrated__pc = convertedLead.Donations_Last_365_Days_Migrated__c,
                    First_Visit_Code__c = convertedLead.First_Visit_Code__c
                );

                contactIdsInScope.add(acct.PersonContactId);
                convertedContactIdToLeadMap.put(acct.PersonContactId, convertedLead);
                accountUpdates.add(acctUpdate);
                accountUpdateMap.put(acctUpdate.Id, acctUpdate);
            }
            update accountUpdates;

            for (Task tsk : [
                SELECT Id,
                    WhoId
                FROM Task
                WHERE WhoId IN :contactIdsInScope AND
                Subject = :Constants.FIRST_VISIT_CODE_TASK_SUBJECT
            ]) {
                if (convertedContactIdToLeadMap.get(tsk.WhoId) != null) {
                    Id donorAccountId = convertedContactIdToLeadMap.get(tsk.WhoId).ConvertedAccountId;
                    String donorFirstVisitCode = accountUpdateMap?.get(donorAccountId).First_Visit_Code__c;

                    Task tskUpdate = new Task (
                        Id = tsk.Id,
                        Description = donorFirstVisitCode
                    );
                    taskUpdates.add(tskUpdate);
                }
            }

            if (!taskUpdates.isEmpty()) {
                update taskUpdates;
            }
        }
    }
}