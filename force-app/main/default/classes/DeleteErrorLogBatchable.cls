public without sharing class DeleteErrorLogBatchable implements Database.Batchable<SObject>, Schedulable {

	public static void selfSchedule() {
		DeleteErrorLogBatchable deleteErrorLogsBatch = new DeleteErrorLogBatchable();

		String suffix = '';
		if (Test.isRunningTest()) {
			suffix = ' - ' + String.valueOf((Math.random() * 100));
		}

		//Nightly at 1am
		String CRON_TIME = '0 0 1 * * ?';

		System.schedule('Delete Error Log Records' + suffix, CRON_TIME, deleteErrorLogsBatch);
	}

	public void execute(SchedulableContext sc) {
		DeleteErrorLogBatchable deleteErrorLogsBatch = new DeleteErrorLogBatchable();

		Database.executeBatch(deleteErrorLogsBatch, 200);
	}

	public Database.QueryLocator start(Database.BatchableContext BC) {
		ErrorLogDefaults__c def = ErrorLogDefaults__c.getOrgDefaults();

		if (def.Id == null) {
			def = new ErrorLogDefaults__c();
			insert def;

			//Re Retrieve
			def = ErrorLogDefaults__c.getOrgDefaults();
		}

		//Get all cases that need to be moved to Closed
		String errorLogsToDeleteQuery = ErrorLogSelector.getErrorLogsOlderThan(def.DaysBeforeDelete__c);

		return Database.getQueryLocator(errorLogsToDeleteQuery);
	}

	public void execute(Database.BatchableContext BC, List<ErrorLog__c> scope) {
		delete scope;
	}

	public void finish(Database.BatchableContext BC) {

	}


}