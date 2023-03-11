@IsTest
private without sharing class ErrorLogServiceTest {

	@TestSetup
	static void setup() {
		//Nothing to do in this case
	}

	@IsTest
	static void testNormalCreation() {
		ErrorLog__c log1 = ErrorLogService.createErrorLog('a', 'b',  CONSTANTS.ERRORLOG_TYPE_WARNING,'c', 'd');

		System.assertEquals('a', log1.RecordId__c);
		System.assertEquals('b', log1.Origin__c);
		System.assertEquals('c', log1.ShortMessage__c);
		System.assertEquals('d', log1.LongMessage__c);
		System.assertEquals(CONSTANTS.ERRORLOG_TYPE_WARNING, log1.Type__c);
	}

	@IsTest
	static void testCreationFromException() {
		ErrorLog__c log1;

		try {
			throw new ErrorLogServiceTestException('PEPE');
		} catch (Exception e) {
			log1 = ErrorLogService.createErrorLogFromException('a', 'b', CONSTANTS.ERRORLOG_TYPE_ERROR, e);
		}

		System.assertEquals('a', log1.RecordId__c);
		System.assertEquals('b', log1.Origin__c);
		System.assertEquals('PEPE', log1.ShortMessage__c);
		System.assertEquals(CONSTANTS.ERRORLOG_TYPE_ERROR, log1.Type__c);
	}

	@IsTest
	static void testLogError() {
		Test.startTest();
		ErrorLogService.logError('0012200000Ve6t9','Unit Test','Short Message','Long Message','addInfo');
		Test.stopTest();
		List<ErrorLog__c> logs = [Select RecordId__c,ErrorDate__c,Origin__c,ShortMessage__c,LongMessage__c,Type__c,AdditionalInfo__c From ErrorLog__c];
		System.assertEquals('0012200000Ve6t9', logs[0].RecordId__c);
		System.assertEquals('Unit Test', logs[0].Origin__c);
		System.assertEquals('Short Message', logs[0].ShortMessage__c);
		System.assertEquals('Long Message', logs[0].LongMessage__c);
		System.assertEquals('addInfo', logs[0].AdditionalInfo__c);
	}

	public class ErrorLogServiceTestException extends Exception {}
}