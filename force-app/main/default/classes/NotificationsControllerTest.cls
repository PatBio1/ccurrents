@isTest
public with sharing class NotificationsControllerTest {

    @isTest
    static void testGetNotificationsDonor() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createAdminUser()) {
            Message__c message = new Message__c();
            message.Donor__c = experienceUser.ContactId;
            message.Name = 'Subject';
            message.Body__c = 'Body';
            message.Expiration_Date__c = Date.today().addDays(5);

            Message__c expiredMessage = new Message__c();
            expiredMessage.Donor__c = experienceUser.ContactId;
            expiredMessage.Name = 'Expired Subject';
            expiredMessage.Body__c = 'Expired Body';
            expiredMessage.Expiration_Date__c = Date.today().addDays(-5);

            insert new List<Message__c>{message, expiredMessage};
        }

        System.runAs(experienceUser) {
            List<NotificationsController.Notification> notifications = NotificationsController.getNotifications(null);

            System.assertEquals(1, notifications.size());
            System.assertEquals('Subject', notifications[0].subject);
            System.assertEquals('Body', notifications[0].body);
        }
    }

    @isTest
    static void testGetNotificationsCenter() {
        User experienceUser = TestUtil.createExperienceUser();
        Account center;

        System.runAs(TestUtil.createAdminUser()) {
            center = TestUtil.createMiramarCenter();
            insert center;

            Message__c message = new Message__c();
            message.Center__c = center.Id;
            message.Name = 'Subject';
            message.Body__c = 'Body';
            message.Expiration_Date__c = Date.today().addDays(5);

            Message__c expiredMessage = new Message__c();
            expiredMessage.Center__c = center.Id;
            expiredMessage.Name = 'Expired Subject';
            expiredMessage.Body__c = 'Expired Body';
            expiredMessage.Expiration_Date__c = Date.today().addDays(-5);

            insert new List<Message__c>{message, expiredMessage};
        }

        System.runAs(experienceUser) {
            List<NotificationsController.Notification> notifications = NotificationsController.getNotifications(center.Id);

            System.assertEquals(1, notifications.size());
            System.assertEquals('Subject', notifications[0].subject);
            System.assertEquals('Body', notifications[0].body);
        }
    }

    @isTest
    static void testGetNotificationsException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                NotificationsController.getNotifications(null);
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testViewNotification() {
        User experienceUser = TestUtil.createExperienceUser();
        Message__c message;

        System.runAs(TestUtil.createAdminUser()) {
            message = new Message__c();
            message.Donor__c = experienceUser.ContactId;
            message.Name = 'Subject';
            message.Body__c = 'Body';
            message.Expiration_Date__c = Date.today().addDays(5);
            insert message;
        }

        System.runAs(experienceUser) {
            NotificationsController.Notification notification = NotificationsController.viewNotification(message.Id);

            System.assertEquals('Subject', notification.subject);
            System.assertEquals('Body', notification.body);
        }
    }

    @isTest
    static void testViewNotificationsException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceGuestUser()) {
            Boolean exceptionThrown = false;

            try {
                NotificationsController.viewNotification(null);
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

}