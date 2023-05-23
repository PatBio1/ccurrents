@IsTest
public without sharing class UserCreationQueueableTest {

    @IsTest
    static void testUpdateAccountWithUser() {
        Account center;
        User experienceUser;
        Account testDonorAccount;

        System.runAs(TestUtil.createAdminUser()) {
            center = TestUtil.createMiramarCenter();
            insert center;

            testDonorAccount = TestUtil.createDonor('123-456');
            insert testDonorAccount;

            Contact testDonorContact = [SELECT Id FROM Contact WHERE Id IN (SELECT PersonContactId FROM Account WHERE Id = :testDonorAccount.Id) LIMIT 1];

            experienceUser = TestUtil.createExperienceUserFromContactId(testDonorContact.Id);
        }

        Test.startTest();

        System.enqueueJob(new UserCreationQueueable(center.Id, testDonorAccount.Id, '', experienceUser.Id));

        Test.stopTest();

        Account testAccount = [SELECT User__pc FROM Account WHERE Id = :testDonorAccount.Id LIMIT 1];
        Assert.isNotNull(testAccount.User__pc, 'Experience user account should have been found');
        Assert.areEqual(experienceUser.Id, testAccount.User__pc, 'Experience user account should have been updated with the experience user id');
    }

}