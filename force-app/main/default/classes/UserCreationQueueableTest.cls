@IsTest
public without sharing class UserCreationQueueableTest {
    @IsTest
    static void testUpdateAccountWithUser() {
        User experienceUser;
        Account testDonorAccount;

        System.runAs(TestUtil.createAdminUser()) {
            testDonorAccount = TestUtil.createDonor('123-456');
            insert testDonorAccount;

            Contact testDonorContact = [SELECT Id FROM Contact WHERE Id IN (SELECT PersonContactId FROM Account WHERE Id = :testDonorAccount.Id) LIMIT 1];

            experienceUser = TestUtil.createExperienceUserFromContactId(testDonorContact.Id);
        }

        Test.startTest();
        System.enqueueJob(new UserCreationQueueable(testDonorAccount.Id, '', experienceUser.Id));
        Test.stopTest();

        Account testAccount = [SELECT Id, User__pc FROM Account WHERE Id = :testDonorAccount.Id LIMIT 1];
        Assert.isNotNull(testAccount.User__pc, 'Experience user account should have been found');
        Assert.areEqual(experienceUser.Id, testAccount.User__pc, 'Experience user account should have been updated with the experience user id');
    }
}