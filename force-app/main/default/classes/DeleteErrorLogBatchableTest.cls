@IsTest
private without sharing class DeleteErrorLogBatchableTest {


	@IsTest
	static void testBehaviorWithOrgDefaults() {

		ErrorLogDefaults__c def = ErrorLogDefaults__c.getOrgDefaults();

		def.DaysBeforeDelete__c = 90.0;
		upsert def;

		List<ErrorLog__c> errorLogs = new List<ErrorLog__c>();

		//Created too recently
		errorLogs.add(new ErrorLog__c(ShortMessage__c = 'Keep 1', Type__c = CONSTANTS.ERRORLOG_TYPE_ERROR));
		//Will be deleted
		errorLogs.add(new ErrorLog__c(ShortMessage__c = 'Delete 1', Type__c = CONSTANTS.ERRORLOG_TYPE_ERROR));
		errorLogs.add(new ErrorLog__c(ShortMessage__c = 'Delete 2', Type__c = CONSTANTS.ERRORLOG_TYPE_ERROR));

		insert errorLogs;

		Test.setCreatedDate(errorLogs[0].Id, Datetime.now().addDays(-100));
		Test.setCreatedDate(errorLogs[1].Id, Datetime.now().addDays(-101));

		Test.startTest();

		DeleteErrorLogBatchable deleteErrorLogsBatch = new DeleteErrorLogBatchable();

		Database.executeBatch(deleteErrorLogsBatch, 10);

		Test.stopTest();

		errorLogs = [
				SELECT Id
				FROM ErrorLog__c
		];

		System.assertEquals(1, errorLogs.size());


	}

	@IsTest
	static void testBehaviorWithoutOrgDefaults() {

		List<ErrorLog__c> errorLogs = new List<ErrorLog__c>();

		//Created too recently
		errorLogs.add(new ErrorLog__c(ShortMessage__c = 'Keep 1', Type__c = CONSTANTS.ERRORLOG_TYPE_ERROR));
		//Will be deleted
		errorLogs.add(new ErrorLog__c(ShortMessage__c = 'Delete 1', Type__c = CONSTANTS.ERRORLOG_TYPE_ERROR));
		errorLogs.add(new ErrorLog__c(ShortMessage__c = 'Delete 2', Type__c = CONSTANTS.ERRORLOG_TYPE_ERROR));

		insert errorLogs;

		Test.setCreatedDate(errorLogs[0].Id, Datetime.now().addDays(-100));
		Test.setCreatedDate(errorLogs[1].Id, Datetime.now().addDays(-101));

		Test.startTest();

		DeleteErrorLogBatchable deleteErrorLogsBatch = new DeleteErrorLogBatchable();

		Database.executeBatch(deleteErrorLogsBatch, 10);

		Test.stopTest();

		errorLogs = [
				SELECT Id
				FROM ErrorLog__c
		];

		System.assertEquals(1, errorLogs.size());


	}	

	@IsTest
	static void testSchedulable() {

		Test.startTest();

		DeleteErrorLogBatchable.selfSchedule();

		Test.stopTest();

	}
}