@IsTest
public with sharing class AddFundsBatchableTest {
    @IsTest static void testSuccessfulAddFundsRun() {
        DonorCompInvocable.AddFundsRequest addFundRequest1 = new DonorCompInvocable.AddFundsRequest('001000000000001');
        addFundRequest1.comments = new List<String> { 'Test Comment 1' };
        addFundRequest1.total = 100.00;

        DonorCompInvocable.AddFundsRequest addFundRequest2 = new DonorCompInvocable.AddFundsRequest('001000000000002');
        addFundRequest2.comments = new List<String> { 'Test Comment 2' };
        addFundRequest2.total = 200.00;

        DonorCompInvocable.AddFundsRequest addFundRequest3 = new DonorCompInvocable.AddFundsRequest('001000000000003');
        addFundRequest3.comments = new List<String> { 'Test Comment 3' };
        addFundRequest3.total = 300.00;

        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        Database.executeBatch(new AddFundsBatchable(
            new List<DonorCompInvocable.AddFundsRequest> { addFundRequest1, addFundRequest2, addFundRequest3 }
        ));
        Test.stopTest();
    }
}