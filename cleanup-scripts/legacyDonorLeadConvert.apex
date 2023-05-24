List<Contact> contactUpdates = new List<Contact>();
Set<Id> contactsInScope = new Set<Id>();

for (Contact ct : [
    SELECT Id
    FROM Contact
    WHERE
        isLegacyDonor__c = FALSE
]){
    contactsInScope.add(ct.Id);
}


for (Lead ld : [
    SELECT ConvertedContactId
    FROM Lead
    WHERE
        IsConverted = TRUE AND
        isLegacyDonor__c = TRUE AND
        ConvertedContactId IN :contactsInScope
]) {
    Contact ct = new Contact(
        Id = ld.ConvertedContactId,
        isLegacyDonor__c = true
    );
    contactUpdates.add(ct);
}

if (!contactUpdates.isEmpty()) {
    update contactUpdates;
}