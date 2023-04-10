public without sharing class EndOfDayVisitBatchable implements Database.Batchable<SObject>, Schedulable {

    public static String CheckedInStatus = 'Checked-In';
    public static String ScheduledStatus = 'Scheduled';
    public static String NoShowOutcome = 'No Show';

    public static void run() {
        Database.executeBatch(new EndOfDayVisitBatchable());
    }

    public void execute(SchedulableContext sc) {
		EndOfDayVisitBatchable endOfDayVisitBatchable = new EndOfDayVisitBatchable();

		Database.executeBatch(endOfDayVisitBatchable, 200);
	}

    public Database.QueryLocator start(Database.BatchableContext BC) {
        Set<String> statuses = new Set<String>{CheckedInStatus,ScheduledStatus};
        return Database.getQueryLocator([
            SELECT
                Id,
                Outcome__c,
                Status__c
            FROM
                Visit__c
            WHERE
                Appointment__r.Datetime__c <: System.now()
            AND
                Outcome__c = null
            AND
                Status__c IN: statuses
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
        for(Visit__c visit: visits){
            if(visit.Status__c == 'Scheduled'){
                visit.Status__c = 'Complete';
                visit.Outcome__c = 'No Show';
            }else if(visit.Status__c == 'Checked-In'){
                visit.Status__c = 'Complete';
                visit.Outcome__c = 'No Donation';
            }
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