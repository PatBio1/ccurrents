@isTest
public with sharing class ProfileControllerTest {

    @isTest
    static void testUpsertLead() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            ProfileController.Profile profile = new ProfileController.Profile();
            profile.firstName = 'First';
            profile.middleName = 'Middle';
            profile.lastName = 'Last';

            Id leadId = ProfileController.upsertLead(profile);

            Lead lead = [
                SELECT
                    FirstName, MiddleName, LastName
                FROM
                    Lead
                WHERE
                    Id = :leadId
            ];

            System.assertEquals('First', lead.FirstName);
            System.assertEquals('Middle', lead.MiddleName);
            System.assertEquals('Last', lead.LastName);
        }
    }

    @isTest
    static void testUpsertLeadException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.upsertLead(new ProfileController.Profile());
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testCreateUser() {
        System.runAs(TestUtil.createExperienceGuestUser()) {
            Account account = TestUtil.createMiramarCenter();
            insert account;

            Lead lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            insert lead;

            ProfileController.Profile profile = new ProfileController.Profile();
            profile.id = lead.Id;
            profile.centerId = account.Id;

            Id userId = ProfileController.createUser(profile);
/*
            User user = [
                SELECT
                    FirstName, LastName
                FROM
                    User
                WHERE
                    Name = 'Test First Test Last'
            ];

            System.assertEquals('First', user.FirstName);
            System.assertEquals('Last', user.LastName);
*/
        }
    }

    
    @isTest
    static void testCreateUserException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.createUser(new ProfileController.Profile());
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testAssignPermissionSet() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createExperienceGuestUser()) {
            ProfileController.assignPermissionSet(experienceUser.Id);

            List<PermissionSetAssignment> permissionSetAssignments = [
                SELECT
                    Id
                FROM
                    PermissionSetAssignment
                WHERE
                    AssigneeId = :experienceUser.Id
                AND
                    PermissionSet.Label = :Constants.EXPERIENCE_PERMISSION_SET_NAME
            ];

            System.assertEquals(1, permissionSetAssignments.size());
        }
    }

    @isTest
    static void testAssignPermissionSetException() {
        TestUtil.throwException = true;

        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.assignPermissionSet(experienceUser.Id);
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

}