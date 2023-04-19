public without sharing class TxnLineItemTriggerHandler extends TriggerFactory.BaseHandler {
    public override void beforeInsert(List<SObject> newList) {
        rollupTxnLineItemFields((List<Txn_Line_Item__c>) newList);
    }
    
    public override void beforeUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        rollupTxnLineItemFields((List<Txn_Line_Item__c>) newMap.values());
    }

    public void rollupTxnLineItemFields(List<Txn_Line_Item__c> lineItems) {
        // If Txn_Line_Item__c.Type__c = 'Currency' then add Txn_Line_Item__c.Total__c to Txn_Line_Item__c.Transaction__r.Amount_Currency__c field
        // If Txn_Line_Item__c.Type__c = 'Points' then add Txn_Line_Item__c.Total__c to Txn_Line_Item__c.Transaction__r.Amount_Points__c field

        Map<Id, Decimal> currencyMap = new Map<Id, Decimal>();
        Map<Id, Decimal> pointsMap = new Map<Id, Decimal>();

        for (Txn_Line_Item__c lineItem : lineItems) {
            if (lineItem.Type__c == 'Currency') {
                if (currencyMap.containsKey(lineItem.Transaction__c)) {
                    currencyMap.put(lineItem.Transaction__c, currencyMap.get(lineItem.Transaction__c) + lineItem.Total__c);
                } else {
                    currencyMap.put(lineItem.Transaction__c, lineItem.Total__c);
                }
            } else if (lineItem.Type__c == 'Points') {
                if (pointsMap.containsKey(lineItem.Transaction__c)) {
                    pointsMap.put(lineItem.Transaction__c, pointsMap.get(lineItem.Transaction__c) + lineItem.Total__c);
                } else {
                    pointsMap.put(lineItem.Transaction__c, lineItem.Total__c);
                }
            }
        }

        Map<Id, Transaction__c> transactions = new Map<Id, Transaction__c>();
        for (Id transactionId : currencyMap.keySet()) {
            Transaction__c txnRecord = transactions.get(transactionId);
            if (txnRecord == null) {
                txnRecord = new Transaction__c(Id = transactionId);
            }

            txnRecord.Amount_Currency__c = currencyMap.get(transactionId);
            transactions.put(transactionId, txnRecord);
        }

        for (Id transactionId : pointsMap.keySet()) {
            Transaction__c txnRecord = transactions.get(transactionId);
            if (txnRecord == null) {
                txnRecord = new Transaction__c(Id = transactionId);
            }

            txnRecord.Amount_Points__c = pointsMap.get(transactionId);
            transactions.put(transactionId, txnRecord);
        }

        update transactions.values();
    }
}