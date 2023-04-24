public without sharing class EndOfDayVisitBatchable implements Database.Batchable<SObject>, Schedulable, Database.Stateful {
    final static String VISIT_STATUS_NEW = 'New';
    final static String VISIT_STATUS_SCHEDULED = 'Scheduled';
    final static String VISIT_STATUS_CHECKED_IN = 'Checked-In';
    final static String VISIT_STATUS_COMPLETE = 'Complete';

    Group proesisOperationsQueue; // Fallback queue in case a center manager queue can't be found
    Map<String, Group> centerManagerQueues;

    public static void run() {
        Database.executeBatch(new EndOfDayVisitBatchable());
    }

    public void execute(SchedulableContext sc) {
		EndOfDayVisitBatchable endOfDayVisitBatchable = new EndOfDayVisitBatchable();

		Database.executeBatch(endOfDayVisitBatchable, 200);
	}

    public Database.QueryLocator start(Database.BatchableContext BC) {
        // Initialize the center manager queues
        centerManagerQueues = new Map<String, Group>();

        for (Group targetedQueue : [SELECT Id, DeveloperName FROM Group WHERE Type = 'Queue' AND (DeveloperName LIKE 'Center_Manager_%' OR DeveloperName = 'Proesis_Operations')]) {
            if (targetedQueue.DeveloperName == 'Proesis_Operations') {
                proesisOperationsQueue = targetedQueue;
            } else if (targetedQueue.DeveloperName.startsWith('Center_Manager_')) {
                centerManagerQueues.put(targetedQueue.DeveloperName, targetedQueue);
            }
        }

        // Query all incomplete visits in the past so we can update them
        Set<String> visitStatuses = new Set<String>{ VISIT_STATUS_NEW, VISIT_STATUS_SCHEDULED, VISIT_STATUS_CHECKED_IN };

        return Database.getQueryLocator([
            SELECT Id, Outcome__c, Status__c, Donation_Volume__c, Center_Donation_Type__r.Center__r.Name, Donor__c
            FROM Visit__c
            WHERE Appointment__r.Datetime__c < :System.now() AND
                (Outcome__c = null OR Status__c IN :visitStatuses)
        ]);
    }

    public void execute(Database.BatchableContext context, List<Visit__c> visits) {
		Savepoint sp = Database.setSavepoint();
        try {
            process_visits(visits);
        } catch (Exception e) {
            Database.rollback(sp);
            System.abortJob(context.getJobId());
        }
	}

    public void process_visits(List<Visit__c> visits) {
        List<Task> tasksToInsert = new List<Task>();

        for(Visit__c visit: visits) {
            String visitStatus = visit.Status__c;

            if (visitStatus != VISIT_STATUS_COMPLETE) {
                if (visitStatus == VISIT_STATUS_NEW) {
                    visit.Outcome__c = 'Canceled';
                } else if (visitStatus == VISIT_STATUS_SCHEDULED) {
                    visit.Outcome__c = 'No Show';
                } else if (visitStatus == VISIT_STATUS_CHECKED_IN) {
                    visit.Outcome__c = 'No Donation';
                }

                visit.Status__c = VISIT_STATUS_COMPLETE;
            } else {
                if (visit.Donation_Volume__c == null || visit.Donation_Volume__c <= 0) {
                    visit.Outcome__c = 'No Donation';
                    continue;
                }
                
                visit.Outcome__c = 'Donation';

                // Make a task noting a visit with a donation was made but wasn't recorded
                Group targetQueue = centerManagerQueues.get('Center_Manager_' + visit.Center_Donation_Type__r.Center__r.Name.replaceAll(' ', '_'));
                if (targetQueue == null && proesisOperationsQueue != null) {
                    targetQueue = proesisOperationsQueue;
                } else {
                    throw new QueryException('No queue found for center ' + visit.Center_Donation_Type__r.Center__r.Name);
                }

                tasksToInsert.add(new Task(
                    WhoId = visit.Donor__c,
                    WhatId = visit.Id,
                    Subject = Constants.UNMARKED_DONATION_TASK_SUBJECT,
                    Description = Constants.UNMARKED_DONATION_TASK_DESCRIPTION,
                    OwnerId = targetQueue.Id
                ));
            }
        }

        if (!tasksToInsert.isEmpty()) {
            insert tasksToInsert;
        }

        update visits;
    }

	public void finish(Database.BatchableContext BC) {

	}

    public static void scheduleDaily() {

		EndOfDayVisitBatchable endOfDayVisitBatchable = new EndOfDayVisitBatchable();

		String suffix = '';
		if (Test.isRunningTest()) {
			suffix = ' - ' + String.valueOf((Math.random() * 100));
		}

		//Nightly at 12am
		String CRON_TIME = '0 0 0 * * ?';

		System.schedule('End of Day Visit Status Updates' + suffix, CRON_TIME, endOfDayVisitBatchable);
	}
    
}