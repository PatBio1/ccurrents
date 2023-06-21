List<Txn_Line_Item__c> lineItemsToInsert = new List<Txn_Line_Item__c>();

for(Transaction__c txn : [
    SELECT Id
    FROM Transaction__c 
    WHERE SubType__c = 'Donation Payment' AND 
        (Amount_Points__c = null OR Amount_Points__c = 0)
]) {
    lineItemsToInsert.add(new Txn_Line_Item__c(
        Unit_Cost__c = 50, // Currently, all donor's are at the $50 level
        Quantity__c = 1,
        Item__c = 'Donation Points',
        Type__c = 'Points',
        Transaction__c = txn.Id
    ));
}

insert lineItemsToInsert;