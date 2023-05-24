@isTest
public with sharing class AccountContactRelationTriggerHandlerTest {

    @isTest
    static void testShareRecords() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createAdminUser()) {
            Contact contact = [SELECT AccountId FROM Contact WHERE Id = :experienceUser.ContactId];

            Group centerAdminGroup = new Group();
            centerAdminGroup.Name = 'Admin';

            Group centerStaffGroup = new Group();
            centerStaffGroup.Name = 'Staff';

            insert new List<Group>{centerAdminGroup, centerStaffGroup};

            Account center = TestUtil.createMiramarCenter();
            insert center;

            AccountShare centerAdminAccountShare = new AccountShare();
            centerAdminAccountShare.AccountId = center.Id;
            centerAdminAccountShare.UserOrGroupId = centerAdminGroup.Id;
            centerAdminAccountShare.RowCause = 'Manual';
            centerAdminAccountShare.AccountAccessLevel = 'Edit';
            centerAdminAccountShare.OpportunityAccessLevel = 'Read';

            AccountShare centerStaffAccountShare = new AccountShare();
            centerStaffAccountShare.AccountId = center.Id;
            centerStaffAccountShare.UserOrGroupId = centerStaffGroup.Id;
            centerStaffAccountShare.RowCause = 'Manual';
            centerStaffAccountShare.AccountAccessLevel = 'Read';
            centerStaffAccountShare.OpportunityAccessLevel = 'Read';

            insert new List<AccountShare>{centerAdminAccountShare, centerStaffAccountShare};

            AccountContactRelation accountContactRelation = new AccountContactRelation();
            accountContactRelation.AccountId = center.Id;
            accountContactRelation.ContactId = contact.Id;
            accountContactRelation.Roles = 'Donor';
            insert accountContactRelation;

            System.assertEquals(1, [SELECT COUNT() FROM AccountShare WHERE AccountId = :contact.AccountId AND UserOrGroupId = :centerAdminGroup.Id]);
            System.assertEquals(1, [SELECT COUNT() FROM AccountShare WHERE AccountId = :contact.AccountId AND UserOrGroupId = :centerStaffGroup.Id]);
        }
    }

}