public without sharing class TransactionSelector {
    @AuraEnabled
    public static List<DonorTransaction> getUserTransactions(){
        List<Transaction__c> transactionRecords;
        try {
            Id targetDonorId = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1]?.ContactId;

            transactionRecords = [
                SELECT Id, Name, Amount_Currency__c, Amount_Points__c, CreatedDate, (SELECT Id, Item__c, Total__c, Type__c FROM Txn_Line_Items__r) 
                FROM Transaction__c 
                WHERE Donor__c = :targetDonorId AND
                    Type__c = 'Debit' AND 
                    Status__c = 'Complete'
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        List<DonorTransaction> transactionWrappers = new List<DonorTransaction>();
        for (Transaction__c transactionRecord : transactionRecords) {
            transactionWrappers.add(new DonorTransaction(transactionRecord));
        }

        return transactionWrappers;
    }

    public class DonorTransaction {
        @AuraEnabled
        public Id transactionId;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public Decimal currencyTotal;
        @AuraEnabled
        public Decimal pointTotal;
        @AuraEnabled
        public DateTime transactionDate;
        @AuraEnabled
        public List<TransactionLineItem> transactionLineItems;

        public DonorTransaction(Transaction__c transactionRecord) {
            this.transactionId = transactionRecord.Id;
            this.name = transactionRecord.Name;
            this.currencyTotal = transactionRecord.Amount_Currency__c;
            this.pointTotal = transactionRecord.Amount_Points__c;
            this.transactionDate = transactionRecord.CreatedDate;

            transactionLineItems = new List<TransactionLineItem>();
            if (transactionRecord.Txn_Line_Items__r != null) {
                for (Txn_Line_Item__c transactionLineItemRecord : transactionRecord.Txn_Line_Items__r) {
                    transactionLineItems.add(new TransactionLineItem(transactionLineItemRecord));
                }
            }
        }
    }

    public class TransactionLineItem {
        @AuraEnabled
        public String itemName;
        @AuraEnabled
        public Decimal currencyTotal;
        @AuraEnabled
        public Decimal pointTotal;

        public TransactionLineItem(Txn_Line_Item__c transactionLineItemRecord) {
            this.itemName = transactionLineItemRecord.Item__c;

            if (transactionLineItemRecord.Type__c == 'Currency') {
                this.currencyTotal = transactionLineItemRecord.Total__c;
                this.pointTotal = 0;
            } else if (transactionLineItemRecord.Type__c == 'Points') {
                this.pointTotal = transactionLineItemRecord.Total__c;
                this.currencyTotal = 0;
            }
        }
    }
}