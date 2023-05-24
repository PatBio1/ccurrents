Map<Id, Lead> leadsInScope = new Map<Id, Lead>();

for (Lead ld : [
    SELECT Id,
        First_Visit_Code__c,
        ConvertedAccount.First_Visit_Code__c
    FROM Lead
    WHERE IsConverted = TRUE AND
    First_Visit_Code__c != NULL AND
    ConvertedAccount.First_Visit_Code__c = NULL
]
) {
    leadsInScope.put(ld.Id, ld);
}
// Use this call when the updated code is deployed to PROD:
// LeadTriggerHandler.updateLegacyDonorMigratedData(leadsInScope);

// Use this copy until then; remove this when the correct code is in PROD
List<Account> accountUpdates = new List<Account>();
Set<Id> accountIdsInScope = new Set<Id>();
Map<Id, Lead> convertedAccountIdToLeadMap = new Map<Id, Lead>();

for (Lead ld : leadsInScope.values()) {
    if (ld.isLegacyDonor__c) {
        accountIdsInScope.add(ld.ConvertedAccountId);
        convertedAccountIdToLeadMap.put(ld.ConvertedAccountId, ld);
    }
}

if (!accountIdsInScope.isEmpty()) {
    List<Account> accountsInScope = [
        SELECT Id,
            Date_Migrated__pc,
            Last_Donation_Date_Migrated__pc,
            Donations_Last_365_Days_Migrated__pc,
            First_Visit_Code__c
        FROM Account
        WHERE isLegacyDonor__pc = FALSE AND
        Id IN :accountIdsInScope
    ];

    if (!accountsInScope.isEmpty()) {
        for (Account acct : accountsInScope) {
            Lead convertedLead = convertedAccountIdToLeadMap.get(acct.Id);
            Account acctUpdate = new Account (
                Id = acct.Id,
                isLegacyDonor__pc = true,
                Date_Migrated__pc = convertedLead.Date_Migrated__c,
                Last_Donation_Date_Migrated__pc = convertedLead.Last_Donation_Date_Migrated__c,
                Donations_Last_365_Days_Migrated__pc = convertedLead.Donations_Last_365_Days_Migrated__c,
                First_Visit_Code__c = convertedLead.First_Visit_Code__c
            );

            accountUpdates.add(acctUpdate);
        }
        update accountUpdates;
    }
}

