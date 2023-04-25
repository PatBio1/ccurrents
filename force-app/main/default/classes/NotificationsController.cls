public without sharing class NotificationsController {

    @AuraEnabled
    public static Boolean hasUnreadNotifications() {
        Integer unreadNotificationCount = 0;

        try {
            unreadNotificationCount = [
                SELECT COUNT()
                FROM Message__c
                WHERE Donor__c IN (SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()) AND
                    isViewed__c = false AND
                    Viewed_Datetime__c = null
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return (unreadNotificationCount > 0);
    }

    @AuraEnabled
    public static List<Notification> getNotifications(Id centerId) {
        try {
            Util.testExceptionHandling();

            List<Message__c> messages;

            // If center is not specified, get donor messages.
            if (centerId == null) {
                User user = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];

                messages = [
                    SELECT
                        Name, Body__c
                    FROM
                        Message__c
                    WHERE
                        Donor__c = :user.ContactId
                    AND
                        (Expiration_Date__c = null OR Expiration_Date__c > :Date.today())
                    ORDER BY
                        CreatedDate DESC
                ];
            }

            // Else get center messages.
            else {
                messages = [
                    SELECT
                        Name, Body__c
                    FROM
                        Message__c
                    WHERE
                        Center__c = :centerId
                    AND
                        (Expiration_Date__c = null OR Expiration_Date__c > :Date.today())
                    ORDER BY
                        CreatedDate DESC
                ];
            }

            List<Notification> notifications = new List<Notification>();

            for (Message__c message : messages) {
                Notification notification = new Notification();
                notification.id = message.Id;
                notification.subject = message.Name;
                notification.body = message.Body__c;
                notifications.add(notification);
            }

            return notifications;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static Notification viewNotification(Id notificationId) {
        try {
            Util.testExceptionHandling();

            Message__c message = [
                SELECT
                    Name, Body__c, Viewed_Datetime__c
                FROM
                    Message__c
                WHERE
                    Id = :notificationId
            ];

            if (message.Viewed_Datetime__c == null) {
                message.isViewed__c = true;
                message.Viewed_Datetime__c = DateTime.now();
                update message;
            }

            Notification notification = new Notification();
            notification.id = message.Id;
            notification.subject = message.Name;
            notification.body = message.Body__c;

            return notification;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }


    public class Notification {

        @AuraEnabled
        public Id id {get; set;}

        @AuraEnabled
        public String subject {get; set;}

        @AuraEnabled
        public String body {get; set;}

    }

}