/**
 * Created by joshlequire1 on 3/13/23.
 */

public class BroadcastActionInvocable {

    @InvocableMethod(Label='Execute Broadcast Action' Category='Donor' Description='Takes the message configuration from the flow and produces outputs for interaction and messaging.')
    public static List<BroadcastActionResponse> executeBroadcastAction(List<List<BroadcastActionInvocableVariable>> messageConfiguration) {
        BroadcastActionInvocableVariable sendConfiguration = new BroadcastActionInvocableVariable();
        List<BroadcastActionInvocableVariable> messageConfigurationList = messageConfiguration[0];
        sendConfiguration = messageConfigurationList[0];
        Set<String> userIds = new Set<String>();
        List<Message__c> messagesToSend = new List<Message__c>();
        BroadcastActionResponse barOutputToFlow = new BroadcastActionResponse();
        List<BroadcastActionResponse> sendBarsToFlow = new List<BroadcastActionResponse>();
        String messageContent;

        if (sendConfiguration.MessageType == 'Center Closure') {
            messageContent = 'This center will be closed during the following times: ' +
                'Closure Start: ' + String.valueOf(sendConfiguration.ClosureStartDatetime.month()) + '-' + String.valueOf(sendConfiguration.ClosureStartDatetime.day()) + '-' + String.valueOf(sendConfiguration.ClosureStartDatetime.year()) + ' ' + String.valueOf(sendConfiguration.ClosureStartDatetime.hour()) + ':' + minuteHelper(sendConfiguration.ClosureStartDatetime) + ', Closure End: ' + String.valueOf(sendConfiguration.ReopenDatetime.month()) + '-' + String.valueOf(sendConfiguration.ReopenDatetime.day()) + ' ' + String.valueOf(sendConfiguration.ReopenDatetime.hour()) + ':' + minuteHelper(sendConfiguration.ReopenDatetime);
            messageContent = messageContent + '. ' + String.valueOf(sendConfiguration.MessageContent);
        } else {
            messageContent = String.valueOf(sendConfiguration.MessageContent);
        }

        if (sendConfiguration.Audience == 'All Donors for Center') {
            for (User usr : [SELECT Id, ContactId FROM User WHERE ContactId IN (SELECT ContactId FROM AccountContactRelation WHERE AccountId = :sendConfiguration.CenterAccountId AND Roles = 'Donor' AND IsActive = TRUE) AND IsActive = TRUE]) {
                userIds.add(usr.Id);
                Message__c message = new Message__c();
                message.Name = String.valueOf(sendConfiguration.MessageType);
                message.Body__c = messageContent;
                message.Donor__c = usr.ContactId;
                message.Expiration_Date__c = sendConfiguration.MessageExpirationDate;
                message.Scheduled_Send_Time__c = sendConfiguration.ScheduledSendDateTime;
                messagesToSend.add(message);
            }
        } else {
            Map<Id, List<Visit__c>> contactToVisitsMap = new Map<Id, List<Visit__c>>();
            for (Visit__c visit : VisitSelector.getVisitsInDateRange(sendConfiguration.DonorScheduleStart, sendConfiguration.DonorScheduleEnd)) {
                List<Visit__c> contactVisitsForPeriod = new List<Visit__c>();
                if (contactToVisitsMap.get(visit.Donor__c) != null) {
                    contactVisitsForPeriod.addAll(contactToVisitsMap.get(visit.Donor__c));
                }
                contactVisitsForPeriod.add(visit);
                contactToVisitsMap.put(visit.Donor__c, contactVisitsForPeriod);
            }

            for (User usr : [SELECT Id, ContactId FROM User WHERE ContactId IN :contactToVisitsMap.keySet() AND IsActive = TRUE]) {
                userIds.add(usr.Id);
                for (Visit__c visit : contactToVisitsMap.get(usr.ContactId)) {
                    Message__c message = new Message__c();
                    message.Name = String.valueOf(sendConfiguration.MessageType);
                    message.Body__c = messageContent;
                    message.Donor__c = usr.ContactId;
                    message.Expiration_Date__c = sendConfiguration.MessageExpirationDate;
                    message.Scheduled_Send_Time__c = sendConfiguration.ScheduledSendDateTime;
                    message.Visit__c = visit.Id;
                    messagesToSend.add(message);
                }
            }
        }

        barOutputToFlow.donorUserIds = new List<String>(userIds);
        barOutputToFlow.donorCount = userIds.size();
        barOutputToFlow.messageRecords = messagesToSend;
        barOutputToFlow.finalMessageText = messageContent;
        sendBarsToFlow.add(barOutputToFlow);

        return sendBarsToFlow;
    }

    public class BroadcastActionResponse {
        @AuraEnabled @InvocableVariable
        public List<String> donorUserIds;

        @AuraEnabled @InvocableVariable
        public Integer donorCount;

        @AuraEnabled @InvocableVariable
        public List<Message__c> messageRecords;

        @AuraEnabled @InvocableVariable
        public String finalMessageText;
    }

    public static String minuteHelper(Datetime dt){
        String returnValue;
        if(dt.minute() == 0) {
            returnValue = '00';
        } else {
            returnValue = String.valueOf(dt);
        }
        return returnValue;
    }

}