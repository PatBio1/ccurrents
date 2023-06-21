public without sharing class TransactionSelector {
    @AuraEnabled
    public static List<DonorTransaction> getUserTransactions(){
        List<Transaction__c> transactionRecords;
        try {
            Id targetDonorId = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1]?.ContactId;

            transactionRecords = [
                SELECT Id, Name, Amount_Currency__c, Amount_Points__c, CreatedDate, (SELECT Id, Item__c, Total__c, Type__c FROM Txn_Line_Items__r), Visit__c, Type__c, SubType__c 
                FROM Transaction__c 
                WHERE Donor__c = :targetDonorId AND
                    Status__c = 'Complete'
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        List<DonorTransaction> transactionWrappers = new List<DonorTransaction>();
        Map<Id, DonorTransaction> visitIdToTransactionWrapper = new Map<Id, DonorTransaction>();

        for (Transaction__c transactionRecord : transactionRecords) {
            DonorTransaction transactionWrapper;

            if (transactionRecord.SubType__c == 'Point Redemption') {
                if (transactionRecord.Type__c == 'Credit') {
                    continue;
                }

                transactionWrapper = new DonorTransaction(transactionRecord);
                transactionWrappers.add(transactionWrapper);

                for(Txn_Line_Item__c transactionLineItemRecord : transactionRecord.Txn_Line_Items__r) {
                    if (transactionLineItemRecord.Type__c == 'Currency') {
                        transactionWrapper.addCurrency(transactionLineItemRecord);
                    } else if (transactionLineItemRecord.Type__c == 'Points') {
                        transactionWrapper.addPoints(transactionLineItemRecord);
                    }
                }
            } else {
                transactionWrapper = visitIdToTransactionWrapper.get(transactionRecord.Visit__c);

                if (transactionWrapper == null) {
                    transactionWrapper = new DonorTransaction(transactionRecord);

                    visitIdToTransactionWrapper.put(transactionRecord.Visit__c, transactionWrapper);
                    transactionWrappers.add(transactionWrapper);
                }

                for(Txn_Line_Item__c transactionLineItemRecord : transactionRecord.Txn_Line_Items__r) {
                    if (transactionLineItemRecord.Type__c == 'Currency' && transactionRecord.Type__c == 'Debit') {
                        transactionWrapper.addCurrency(transactionLineItemRecord);
                    } else if (transactionLineItemRecord.Type__c == 'Points' && transactionRecord.Type__c == 'Credit') {
                        transactionWrapper.addPoints(transactionLineItemRecord);
                    }
                }
            }
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
            this.transactionDate = transactionRecord.CreatedDate;

            this.currencyTotal = 0;
            this.pointTotal = 0;

            transactionLineItems = new List<TransactionLineItem>();
        }

        public void addPoints(Txn_Line_Item__c pointLineItem) {
            this.pointTotal += pointLineItem.Total__c;
            transactionLineItems.add(new TransactionLineItem(pointLineItem));
        }

        public void addCurrency(Txn_Line_Item__c currencyLineItem) {
            this.currencyTotal += currencyLineItem.Total__c;
            transactionLineItems.add(new TransactionLineItem(currencyLineItem));
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