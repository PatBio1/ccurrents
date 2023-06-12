List<Contact> donorContactsToUpdate = new List<Contact>();
Level__c defaultLevel = LoyaltyLevelService.getDefault();

for(Contact donorContact : [SELECT Id FROM Contact WHERE Loyalty_Level__c = null]) {
    donorContact.Loyalty_Level__c = defaultLevel.Id;
    donorContactsToUpdate.add(donorContact);
}

update donorContactsToUpdate;