public without sharing class AddFundsBatchable implements System.Schedulable, Database.Batchable<ProesisAddFundsRequest>, Database.AllowsCallouts, Database.Stateful {
    public static String jobNameSearchString = 'Onbe - Add Funds Retry%';
    
    List<ProesisAddFundsRequest> addFundRequests;
    Boolean isRetry;

    // IF no specific requests are passed in, then we will look for any Add Funds Requests awaiting retry
    public AddFundsBatchable() {
        this.addFundRequests = null;
        this.isRetry = true;
    }

    public AddFundsBatchable(List<ProesisAddFundsRequest> addFundRequests) {
        AddFundsBatchableHelper.createDebitTransactionsWithLineItems(addFundRequests);

        this.addFundRequests = addFundRequests;
        this.isRetry = false;
    }

    public Iterable<ProesisAddFundsRequest> start(Database.BatchableContext bc) {
        Proesis_Settings__c proesisSettings = Proesis_Settings__c.getOrgDefaults();
        Decimal paymentServiceMaxRetry = proesisSettings.Payment_Service_Max_Retry__c;

        if (paymentServiceMaxRetry == null) {
            paymentServiceMaxRetry = 10; // default per model provided by Tim
        }
        
        if (this.addFundRequests == null || this.addFundRequests.size() == 0) {
            this.addFundRequests = new List<ProesisAddFundsRequest>();
            Map<Id, String> donorIdToActivePaymentMethodNumber = new Map<Id, String>();

            for(Payment_Method__c paymentMethod : [
                SELECT Id, Donor__c, Account_Number__c
                FROM Payment_Method__c
                WHERE Is_Active__c = true AND
                    isDefault__c = true AND 
                    Donor__c IN (
                        SELECT Donor__c 
                        FROM Transaction__c 
                        WHERE Status__c = 'Error' AND 
                            Type__c = 'Debit' AND 
                            (Retry_Next__c = null OR Retry_Next__c <= :System.now()) AND
                            (Retry_Count__c = null OR Retry_Count__c < :paymentServiceMaxRetry)
                    )
            ]) {
                donorIdToActivePaymentMethodNumber.put(paymentMethod.Donor__c, paymentMethod.Account_Number__c);
            }

            for(Transaction__c erroredTransaction : [
                SELECT Id, Donor__c, Visit__c, SubType__c, Onbe_Transaction_Id__c, (SELECT Id, Type__c, Item__c, Total__c FROM Txn_Line_Items__r)
                FROM Transaction__c 
                WHERE Status__c = 'Error' AND 
                    Type__c = 'Debit' AND 
                    (Retry_Next__c = null OR Retry_Next__c <= :System.now()) AND 
                    (Retry_Count__c = null OR Retry_Count__c < :paymentServiceMaxRetry)
            ]) {
                ProesisAddFundsRequest newRetryRequest = new ProesisAddFundsRequest(
                    erroredTransaction.Donor__c,
                    erroredTransaction.Visit__c,
                    donorIdToActivePaymentMethodNumber.get(erroredTransaction.Donor__c),
                    erroredTransaction.SubType__c,
                    erroredTransaction.Id
                );

                if (!String.isEmpty(erroredTransaction.Onbe_Transaction_Id__c)) {
                    newRetryRequest.setOnbeTransactionId(erroredTransaction.Onbe_Transaction_Id__c);
                }

                for(Txn_Line_Item__c lineItem : erroredTransaction.Txn_Line_Items__r) {
                    newRetryRequest.comments.add(lineItem.Item__c);
                    newRetryRequest.addLineItem(lineItem.Item__c, lineItem.Type__c, lineItem.Total__c);
                }

                this.addFundRequests.add(newRetryRequest);
            }
        }

        return this.addFundRequests;
    }

    public void execute(SchedulableContext sc) {
        // Callout limit is 100 per async transaction, therefore no more than 100 records
        // A scheduled run also assumes that we are only retrying errored transactions
        Database.executeBatch(new AddFundsBatchable(), 100);
    }

    public void execute(Database.BatchableContext info, List<ProesisAddFundsRequest> scope) {
        AddFundsBatchableHelper.processAddFundsCallouts(scope);
        AddFundsBatchableHelper.handleAddFundsResponses(scope);
    }

    public void finish(Database.BatchableContext bc) {
        // Make sure to abort any existing scheduled jobs to avoid a naming exception down below
        for(CronTrigger existingOnbeScheduledJob : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE 'Onbe - Add Funds Retry%' AND State IN ('COMPLETE', 'ERROR', 'PAUSED')]) {
            System.abortJob(existingOnbeScheduledJob.Id);
        }

        if (!Test.isRunningTest() && getScheduledRetryJobInstanceCount() > 0) {
            // If there is already another retry scheduled job that hasn't fired yet, then we don't need to schedule another one
            return;
        }
        
        Proesis_Settings__c proesisSettings = Proesis_Settings__c.getOrgDefaults();
        Decimal paymentServiceMaxRetry = proesisSettings.Payment_Service_Max_Retry__c;

        if (paymentServiceMaxRetry == null) {
            paymentServiceMaxRetry = 10; // default per model provided by Tim
        }
        
        // We don't need to filter on the retry next, it should fire if there are any remaining errored transactions that haven't hit max retry count
        Integer remainingErroredTransactions = [
            SELECT count() FROM Transaction__c WHERE Status__c = 'Error' AND 
                Type__c = 'Debit' AND
                (Retry_Count__c = null OR Retry_Count__c < :paymentServiceMaxRetry)
        ];
        
        if (remainingErroredTransactions > 0) {
            scheduledRetryRun();
        }
    }

    public static Integer getScheduledRetryJobInstanceCount() {
        return [SELECT count() FROM CronTrigger WHERE CronJobDetail.Name LIKE :jobNameSearchString AND State IN ('WAITING', 'ACQUIRED')];
    }

    public static void scheduledRetryRun() {
        Datetime currentDateTime = DateTime.now();
        Datetime nextRetryDateTime = currentDateTime.addMinutes(10);

        String cronExpression = String.format('{0} {1} {2} {3} {4} ? {5}', new List<object> {
            nextRetryDateTime.second(),
            nextRetryDateTime.minute(),
            nextRetryDateTime.hour(),
            nextRetryDateTime.day(),
            nextRetryDateTime.month(),
            nextRetryDateTime.year()
        });

        String adjustedHours;
        if (nextRetryDateTime.hour() > 12) {
            adjustedHours = String.valueOf(nextRetryDateTime.hour() - 12);
        } else {
            if (nextRetryDateTime.hour() < 10) {
                adjustedHours = '0' + nextRetryDateTime.hour();
            } else {
                adjustedHours = String.valueOf(nextRetryDateTime.hour());
            }
        }

        String adjustedMinutes = (nextRetryDateTime.minute() < 10) ? '0' + nextRetryDateTime.minute() : String.valueOf(nextRetryDateTime.minute());
        String adjustedSeconds = (nextRetryDateTime.second() < 10) ? '0' + nextRetryDateTime.second() : String.valueOf(nextRetryDateTime.second());
        String adjustedMonth = (nextRetryDateTime.month() < 10) ? '0' + nextRetryDateTime.month() : String.valueOf(nextRetryDateTime.month());
        String adjustedDay = (nextRetryDateTime.day() < 10) ? '0' + nextRetryDateTime.day() : String.valueOf(nextRetryDateTime.day());

        String jobDateKey = String.format(
            '{0}:{1}:{2} {3}/{4}/{5}', new List<object> { 
                adjustedHours, adjustedMinutes, adjustedSeconds, 
                adjustedMonth, adjustedDay, nextRetryDateTime.year() 
            }
        );

        if (Test.isRunningTest() && [SELECT count() FROM CronTrigger WHERE CronJobDetail.Name LIKE :jobNameSearchString] > 0) {
            // Multiple jobs will get queued over and over again in a test context, so we need to make sure we don't schedule more than one
            return;
        } 

        System.schedule(jobNameSearchString.replace('%', '') + ' - ' + jobDateKey, cronExpression, new AddFundsBatchable());
    }
}