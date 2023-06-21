public without sharing class QueueSelector {
    private static Map<Id, Group> centerIdToCenterManagerQueue;

    public static Group getCenterManagerQueue(Id centerAccountId) {
        if (centerIdToCenterManagerQueue == null) {
            Map<String, Account> centerNamestoCenterAccount = new Map<String, Account>();

            for(Account centerAccount : [SELECT Id, Name FROM Account WHERE IsActive__c = true AND RecordType.DeveloperName = 'Center']) {
                String adjustedName = centerAccount.Name.replace('Proesis', '').trim().replaceAll('[^a-zA-Z0-9]', '_');
                centerNamestoCenterAccount.put('Center_Manager_' + adjustedName, centerAccount);
            }

            centerIdToCenterManagerQueue = new Map<Id, Group>();
            for(Group centerManagerQueue : [SELECT Id, DeveloperName FROM Group WHERE DeveloperName IN :centerNamestoCenterAccount.keySet() AND Type = 'Queue']) {
                Account centerAccount = centerNamestoCenterAccount.get(centerManagerQueue.DeveloperName);
                centerIdToCenterManagerQueue.put(centerAccount.Id, centerManagerQueue);
            }
        }

        return centerIdToCenterManagerQueue.get(centerAccountId);
    }
}