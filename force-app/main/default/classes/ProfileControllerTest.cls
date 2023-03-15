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
    static void testSetupPhoto() {
        Lead lead;
        ContentVersion contentVersion;

        System.runAs(TestUtil.createAdminUser()) {
            lead = new Lead();
            lead.FirstName = 'Test First';
            lead.LastName = 'Test Last';
            insert lead;

            contentVersion = TestUtil.createContentVersion();
            insert contentVersion;
        }

        System.runAs(TestUtil.createExperienceGuestUser()) {
            ProfileController.Profile profile = new ProfileController.Profile();
            profile.id = lead.Id;
            profile.photoContentVersionId = contentVersion.Id;

            MobileGuestService.GetDownloadUrlResponse getDownloadUrlResponse = new MobileGuestService.GetDownloadUrlResponse();
            getDownloadUrlResponse.downloadUrl = 'https://test.com';

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new CalloutMock(JSON.serialize(getDownloadUrlResponse)));

            String url = ProfileController.setupPhoto(profile);

            Test.stopTest();

            System.assertEquals('https://test.com', url);
        }
    }

    @isTest
    static void testSetupPhotoException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.setupPhoto(new ProfileController.Profile());
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testRemovePhoto() {
        ContentVersion contentVersion;

        System.runAs(TestUtil.createAdminUser()) {
            contentVersion = TestUtil.createContentVersion();
            insert contentVersion;
        }

        System.runAs(TestUtil.createExperienceGuestUser()) {
            ProfileController.removePhoto(contentVersion.Id);

            System.assertEquals(0, [SELECT COUNT() FROM ContentVersion WHERE Id = :contentVersion.Id]);
        }
    }

    @isTest
    static void testRemovePhotoException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.removePhoto(null);
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
            profile.nickname = 'testnick';

            Id userId = ProfileController.createUser(profile);

            Account personAccount = [
                SELECT ID,
                        First_Visit_Code__c
                FROM Account 
                WHERE Name = 'Test First Test Last' 
            ];

            system.assertEquals(7, personAccount.First_Visit_Code__c.length());

            // Site.createExternalUser() doesn't work in unit tests so the user isn't
            // actually created and the following assertions won't work.
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
    static void testSetupUser() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createExperienceGuestUser()) {
            ProfileController.Profile profile = new ProfileController.Profile();
            profile.userId = experienceUser.Id;

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new CalloutMock(''));

            ProfileController.setupUser(profile);

            Test.stopTest();

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
    static void testSetupUserException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                ProfileController.setupUser(new ProfileController.Profile());
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

}