/**
 * Created by joshlequire1 on 2/28/23.
 */

public with sharing class LeadTriggerHandler extends TriggerFactory.BaseHandler {
    public static Boolean bypassTrigger = false;

    public override void afterUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        if (bypassTrigger) {
            return;
        }

        Set<Id> convertedLeadIds = getConvertedLeadIds((Map<Id, Lead>) oldMap, (Map<Id, Lead>) newMap);

        if (!convertedLeadIds.isEmpty()) {
            updateConsentTransactionLinksOnConversion((Map<Id, Lead>) newMap, convertedLeadIds);
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

    public static void updateLegacyDonorMigratedData(Map<Id, Lead> newLeadMap, Set<Id> convertedLeadIds) {
        List<Contact> contactUpdates = new List<Contact>();
        Set<Id> contactsIdsInScope = new Set<Id>();
        Map<Id, Lead> convertedContactIdToLeadMap = new Map<Id, Lead>();

        for (Lead ld : newLeadMap.values()) {
            if (ld.isLegacyDonor__c) {
                contactsIdsInScope.add(ld.ConvertedContactId);
                convertedContactIdToLeadMap.put(ld.ConvertedContactId, ld);
            }
        }

        if (!contactsIdsInScope.isEmpty()) {
            List<Contact> contactsInScope = [
                SELECT Id,
                    Date_Migrated__c,
                    Last_Donation_Date_Migrated__c,
                    Donations_Last_365_Days_Migrated__c
                FROM Contact
                WHERE isLegacyDonor__c = FALSE AND
                Id IN :contactsIdsInScope
            ];

            if (!contactsInScope.isEmpty()) {
                for (Contact ct : contactsInScope) {
                    Lead convertedLead = convertedContactIdToLeadMap.get(ct.Id);
                    Contact ctUpdate = new Contact (
                        Id = ct.Id,
                        isLegacyDonor__c = true,
                        Date_Migrated__c = convertedLead.Date_Migrated__c,
                        Last_Donation_Date_Migrated__c = convertedLead.Last_Donation_Date_Migrated__c,
                        Donations_Last_365_Days_Migrated__c = convertedLead.Donations_Last_365_Days_Migrated__c
                    );

                    contactUpdates.add(ctUpdate);
                }
                update contactUpdates;
            }
        }
    }
}