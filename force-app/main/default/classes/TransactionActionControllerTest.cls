@IsTest
public without sharing class TransactionActionControllerTest {
    @TestSetup
    static void createTestData() {
        Account testDonorAccount = TestUtil.createDonor('123-456');
        insert testDonorAccount;

        Id testDonorContactId = [SELECT PersonContactId FROM Account WHERE Id = :testDonorAccount.Id].PersonContactId;
        Transaction__c testTransaction = new Transaction__c(
            Donor__c = testDonorContactId,
            Status__c = 'Error',
            Retry_Count__c = 5, 
            Retry_Next__c = System.now().addMinutes(5),
            Was_Manually_Processed__c = false
        );
        insert testTransaction;
    }

    @IsTest
    public static void testMarkTransactionForRetry() {
        Transaction__c testTransaction = [SELECT Id, Status__c, Retry_Count__c, Retry_Next__c FROM Transaction__c LIMIT 1];
        Transaction__c updatedTransaction;

        Test.startTest();
        updatedTransaction = TransactionActionController.markTransactionForRetry(testTransaction.Id);
        Test.stopTest();

        Assert.areEqual(testTransaction.Id, updatedTransaction.Id, 'The correct transaction was returned from the quick action');
        Assert.areEqual(0, updatedTransaction.Retry_Count__c, 'The retry count was reset to 0');
        Assert.isNull(updatedTransaction.Retry_Next__c, 'The retry next date was reset to null');
    }

    @IsTest 
    public static void testMarkTransactionAsManualPayment() {
        Transaction__c testTransaction = [SELECT Id, Status__c, Was_Manually_Processed__c FROM Transaction__c LIMIT 1];
        Transaction__c updatedTransaction;

        Test.startTest();
        updatedTransaction = TransactionActionController.markTransactionAsManualPayment(testTransaction.Id);
        Test.stopTest();

        Assert.areEqual(testTransaction.Id, updatedTransaction.Id, 'The correct transaction was returned from the quick action');
        Assert.isTrue(updatedTransaction.Was_Manually_Processed__c, 'The transaction was marked as manually processed');
        Assert.areEqual('Complete', updatedTransaction.Status__c, 'The transaction Status was updated to Complete');
    }
}