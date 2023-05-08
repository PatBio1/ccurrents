@isTest
public with sharing class MessageTriggerHandlerTest {

    @isTest
    static void testShareRecords() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createAdminUser()) {
            Contact contact = [SELECT AccountId FROM Contact WHERE Id = :experienceUser.ContactId];

            Group contactAdminGroup = new Group();
            contactAdminGroup.Name = 'Admin';

            Group contactStaffGroup = new Group();
            contactStaffGroup.Name = 'Staff';

            Group centerAdminGroup = new Group();
            centerAdminGroup.Name = 'Admin';

            Group centerStaffGroup = new Group();
            centerStaffGroup.Name = 'Staff';

            insert new List<Group>{contactAdminGroup, contactStaffGroup, centerAdminGroup, centerStaffGroup};

            Account center = TestUtil.createMiramarCenter();
            insert center;

            AccountShare contactAdminAccountShare = new AccountShare();
            contactAdminAccountShare.AccountId = center.Id;
            contactAdminAccountShare.UserOrGroupId = contactAdminGroup.Id;
            contactAdminAccountShare.RowCause = 'Manual';
            contactAdminAccountShare.AccountAccessLevel = 'Read';
            contactAdminAccountShare.OpportunityAccessLevel = 'Read';

            AccountShare contactStaffAccountShare = new AccountShare();
            contactStaffAccountShare.AccountId = center.Id;
            contactStaffAccountShare.UserOrGroupId = contactStaffGroup.Id;
            contactStaffAccountShare.RowCause = 'Manual';
            contactStaffAccountShare.AccountAccessLevel = 'Read';
            contactStaffAccountShare.OpportunityAccessLevel = 'Read';

            AccountShare centerAdminAccountShare = new AccountShare();
            centerAdminAccountShare.AccountId = center.Id;
            centerAdminAccountShare.UserOrGroupId = centerAdminGroup.Id;
            centerAdminAccountShare.RowCause = 'Manual';
            centerAdminAccountShare.AccountAccessLevel = 'Read';
            centerAdminAccountShare.OpportunityAccessLevel = 'Read';

            AccountShare centerStaffAccountShare = new AccountShare();
            centerStaffAccountShare.AccountId = center.Id;
            centerStaffAccountShare.UserOrGroupId = centerStaffGroup.Id;
            centerStaffAccountShare.RowCause = 'Manual';
            centerStaffAccountShare.AccountAccessLevel = 'Read';
            centerStaffAccountShare.OpportunityAccessLevel = 'Read';

            insert new List<AccountShare>{contactAdminAccountShare, contactStaffAccountShare, centerAdminAccountShare, centerStaffAccountShare};

            Message__c message = new Message__c();
            message.Center__c = center.Id;
            message.Donor__c = experienceUser.ContactId;
            message.Name = 'Subject';
            message.Body__c = 'Body';
            message.Expiration_Date__c = Date.today().addDays(5);
            insert message;

            System.assertEquals(1, [SELECT COUNT() FROM Message__share WHERE ParentId = :message.Id AND UserOrGroupId = :contactAdminGroup.Id]);
            System.assertEquals(1, [SELECT COUNT() FROM Message__share WHERE ParentId = :message.Id AND UserOrGroupId = :contactStaffGroup.Id]);
            System.assertEquals(1, [SELECT COUNT() FROM Message__share WHERE ParentId = :message.Id AND UserOrGroupId = :centerAdminGroup.Id]);
            System.assertEquals(1, [SELECT COUNT() FROM Message__share WHERE ParentId = :message.Id AND UserOrGroupId = :centerStaffGroup.Id]);
        }
    }

}